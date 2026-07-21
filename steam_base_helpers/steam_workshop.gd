## steam_workshop.gd
## -----------------------------------------------------------------------
## Autoload responsável por criar, publicar, procurar, subscrever e
## carregar itens do Steam Workshop (UGC).
##
## COMO USAR: adiciona como Autoload com o nome "SteamWorkshop".
## Lê a secção "Workshop / UGC" do guia geral para mais contexto.
## -----------------------------------------------------------------------
extends Node

signal item_created(file_id: int)
signal item_create_failed(reason: String)
signal item_published(file_id: int)
signal item_publish_failed(reason: String)
signal search_results_received(items: Array)
signal item_installed(file_id: int)

var published_file_id: int = 0
var _update_handle: int = 0


func _ready() -> void:
	Steam.item_created.connect(_on_item_created)
	Steam.item_updated.connect(_on_item_updated)
	Steam.ugc_query_completed.connect(_on_query_completed)
	Steam.item_installed.connect(_on_item_installed)


## ---------------------------------------------------------------------
## Criar / publicar um novo item
## ---------------------------------------------------------------------

func create_new_item() -> void:
	Steam.createItem(Steam.getAppID(), Steam.WORKSHOP_FILE_TYPE_COMMUNITY)


func _on_item_created(result: int, file_id: int, needs_agreement: bool) -> void:
	if result != Steam.Result.RESULT_OK:
		item_create_failed.emit(str(result))
		return

	published_file_id = file_id
	if needs_agreement:
		Steam.showWorkshopEULA()

	Steam.subscribeItem(file_id)  # não é automático para o criador
	item_created.emit(file_id)


## content_folder: pasta LOCAL com o conteúdo a publicar (ex: ficheiros
## de mapa exportados, um .zip, etc. — o formato é decidido por ti).
## preview_image_path: imagem local usada como thumbnail no Workshop.
func publish_item(
	title: String,
	description: String,
	content_folder: String,
	preview_image_path: String,
	tags: PackedStringArray = [],
	visibility: int = Steam.REMOTE_STORAGE_PUBLISHED_FILE_VISIBILITY_PUBLIC,
	change_notes: String = "Atualização"
) -> void:
	if published_file_id == 0:
		item_publish_failed.emit("nenhum_item_criado")
		return

	_update_handle = Steam.startItemUpdate(Steam.getAppID(), published_file_id)
	Steam.setItemTitle(_update_handle, title)
	Steam.setItemDescription(_update_handle, description)
	Steam.setItemVisibility(_update_handle, visibility)
	if not tags.is_empty():
		Steam.setItemTags(_update_handle, tags)
	Steam.setItemContent(_update_handle, content_folder)
	Steam.setItemPreview(_update_handle, preview_image_path)
	Steam.submitItemUpdate(_update_handle, change_notes)


func _on_item_updated(result: int, _needs_agreement: bool) -> void:
	if result == Steam.Result.RESULT_OK:
		item_published.emit(published_file_id)
	else:
		item_publish_failed.emit(str(result))


## ---------------------------------------------------------------------
## Procurar e subscrever itens de outros utilizadores
## ---------------------------------------------------------------------

func search_workshop_items(page: int = 1) -> void:
	var query_handle: int = Steam.createQueryAllUGCRequest(
		Steam.UGC_QUERY_RANKED_BY_VOTE,
		Steam.UGC_MATCHING_UGC_TYPE_ITEMS,
		Steam.getAppID(),
		Steam.getAppID(),
		page
	)
	Steam.sendQueryUGCRequest(query_handle)


func _on_query_completed(query_handle: int, result: int, results_returned: int, _total_matching: int, _cached: bool) -> void:
	if result != Steam.Result.RESULT_OK:
		search_results_received.emit([])
		return

	var items: Array = []
	for i in range(results_returned):
		items.append(Steam.getQueryUGCResult(query_handle, i))
	search_results_received.emit(items)


func subscribe_to_item(file_id: int) -> void:
	Steam.subscribeItem(file_id)  # o download começa automaticamente


func unsubscribe_from_item(file_id: int) -> void:
	Steam.unsubscribeItem(file_id)


## ---------------------------------------------------------------------
## Carregar itens já instalados localmente
## ---------------------------------------------------------------------

## Devolve Array de Dictionary {file_id, folder} para cada item instalado.
func get_installed_items() -> Array:
	var installed: Array = []
	var subscribed: Array = Steam.getSubscribedItems()
	for file_id in subscribed:
		var info: Dictionary = Steam.getItemInstallInfo(file_id)
		if info.get("ret", false):
			installed.append({"file_id": file_id, "folder": info["folder"]})
	return installed


func _on_item_installed(_app_id: int, file_id: int) -> void:
	item_installed.emit(file_id)
