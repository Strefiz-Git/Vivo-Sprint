extends Node

signal player_started_speaking(peer_id: int)
signal player_stopped_speaking(peer_id: int)

var current_sample_rate: int = 48000
var is_recording: bool = false

var _voice_playbacks: Dictionary = {}
var _voice_buffers: Dictionary = {}

func _ready() -> void:
	if steam_manager.initialized:
		current_sample_rate = Steam.getVoiceOptimalSampleRate()

# --- Voice Node Registration (proximity chat) ---

func register_player_voice_node(peer_id: int, voice_player: AudioStreamPlayer3D) -> void:
	if not voice_player.stream:
		voice_player.stream = AudioStreamGenerator.new()
		voice_player.stream.mix_rate = current_sample_rate
	voice_player.play()
	_voice_playbacks[peer_id] = voice_player.get_stream_playback()
	_voice_buffers[peer_id] = PackedByteArray()

func unregister_player_voice_node(peer_id: int) -> void:
	_voice_playbacks.erase(peer_id)
	_voice_buffers.erase(peer_id)

# --- Recording ---

func start_recording() -> void:
	if is_recording or not steam_manager.initialized:
		return
	is_recording = true
	Steam.setInGameVoiceSpeaking(steam_manager.steam_id, true)
	Steam.startVoiceRecording()

func stop_recording() -> void:
	if not is_recording or not steam_manager.initialized:
		return
	is_recording = false
	Steam.setInGameVoiceSpeaking(steam_manager.steam_id, false)
	Steam.stopVoiceRecording()

func _process(_delta: float) -> void:
	if is_recording:
		_capture_and_send_voice()

func _capture_and_send_voice() -> void:
	var available: Dictionary = Steam.getAvailableVoice()
	if available.get("result") != Steam.Result.RESULT_OK:
		return
	if available.get("buffer", 0) <= 0:
		return
	var voice_data: Dictionary = Steam.getVoice()
	if voice_data.get("result") != Steam.Result.RESULT_OK:
		return
	var compressed: PackedByteArray = voice_data["buffer"]
	_receive_voice_packet.rpc(compressed)

@rpc("any_peer", "call_remote", "unreliable")
func _receive_voice_packet(compressed: PackedByteArray) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not steam_manager.initialized:
		return
	var decompressed: Dictionary = Steam.decompressVoice(compressed, current_sample_rate)
	if decompressed.get("result") != Steam.Result.RESULT_OK:
		return
	if not _voice_buffers.has(sender_id):
		return
	var pcm: PackedByteArray = decompressed["uncompressed"]
	_voice_buffers[sender_id].append_array(pcm)
	player_started_speaking.emit(sender_id)

# --- Playback ---

func _physics_process(_delta: float) -> void:
	for peer_id in _voice_buffers.keys():
		_push_available_frames(peer_id)

func _push_available_frames(peer_id: int) -> void:
	var buffer: PackedByteArray = _voice_buffers.get(peer_id, PackedByteArray())
	if buffer.is_empty():
		return
	var playback: AudioStreamGeneratorPlayback = _voice_playbacks.get(peer_id)
	if not playback:
		return
	var frames_available: int = playback.get_frames_available()
	if frames_available <= 0:
		return
	var frames_to_push: int = mini(frames_available, buffer.size() / 2)
	for i in range(frames_to_push):
		var sample: int = buffer.decode_s16(i * 2)
		var value: float = sample / 32768.0
		playback.push_frame(Vector2(value, value))
	_voice_buffers[peer_id] = buffer.slice(frames_to_push * 2)
	if frames_to_push > 0 and buffer.size() <= frames_to_push * 2:
		player_stopped_speaking.emit(peer_id)
