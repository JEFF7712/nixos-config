.pragma library

function clampedLeft(anchorCenterX, popupWidth, outputWidth, barMargin) {
    if (anchorCenterX < 0)
        return -1;
    const width = Math.max(1, popupWidth);
    const minL = Math.max(0, barMargin);
    const maxL = Math.max(minL, outputWidth - barMargin - width);
    const desired = Math.round(anchorCenterX - width / 2);
    if (desired < minL)
        return minL;
    if (desired > maxL)
        return maxL;
    return desired;
}
