.pragma library

function label(text, identifier) {
    const t = String(text || "").trim();
    if (t)
        return t;
    const id = String(identifier || "").trim();
    const key = id.toLowerCase();
    if (key === "" || key === "default" || key === "open" || key === "activate" || key === "show")
        return "Open";
    if (key === "inline-reply" || key === "inline_reply")
        return "Reply";
    return id.replace(/[-_]+/g, " ");
}
