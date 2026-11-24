.pragma library

// Update a ListModel in place from a plain array: matching rows are `set`,
// so views keep their delegates (no flicker, hover and focus survive), and
// only the length difference is appended or removed.
function sync(model, list) {
    var rows = list || [];
    var shared = Math.min(model.count, rows.length);
    for (var i = 0; i < shared; i++)
        model.set(i, rows[i]);
    if (model.count > rows.length)
        model.remove(rows.length, model.count - rows.length);
    for (var j = shared; j < rows.length; j++)
        model.append(rows[j]);
}
