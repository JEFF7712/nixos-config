.pragma library

function rowKey(rowKind, entityId, roomDeviceId) {
  return rowKind === "room_reading"
    ? "room:" + String(roomDeviceId || "")
    : "entity:" + String(entityId || "")
}

function pinnedVisible(pinned, collapsedPinnedRows, key) {
  var collapsed = Array.isArray(collapsedPinnedRows) ? collapsedPinnedRows : []
  return pinned === true && collapsed.indexOf(String(key || "")) === -1
}

function toggle(collapsedPinnedRows, expandedEntityId, key, entityId,
                currentlyExpanded, pinned) {
  var collapsed = Array.isArray(collapsedPinnedRows)
    ? collapsedPinnedRows.slice() : []
  var expanded = String(expandedEntityId || "")
  var rowKeyValue = String(key || "")
  var rowEntityId = String(entityId || "")
  var collapsedIndex = collapsed.indexOf(rowKeyValue)

  if (currentlyExpanded === true) {
    if (pinned === true && collapsedIndex === -1) collapsed.push(rowKeyValue)
    if (expanded === rowEntityId) expanded = ""
  } else if (pinned === true && collapsedIndex !== -1) {
    collapsed.splice(collapsedIndex, 1)
  } else {
    expanded = rowEntityId
  }

  return {
    collapsedPinnedRows: collapsed,
    expandedEntityId: expanded
  }
}
