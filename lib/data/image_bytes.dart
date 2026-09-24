bool isSupportedImageBytes(List<int>? bytes) {
  if (bytes == null || bytes.isEmpty) {
    return false;
  }
  return isJpegBytes(bytes) || isPngBytes(bytes) || isWebpBytes(bytes);
}

bool isJpegBytes(List<int> bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

bool isPngBytes(List<int> bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

bool isWebpBytes(List<int> bytes) {
  return bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

/// Whether a JPEG/PNG/WebP byte buffer reaches its end marker, i.e. was not
/// cut short by an interrupted download or write. Other formats pass.
bool looksCompleteImageBytes(List<int> bytes) {
  if (isJpegBytes(bytes)) {
    // Entropy-coded data cannot contain FF D9, so a complete JPEG has an
    // end-of-image marker somewhere after its first start-of-scan (FF DA).
    // Data appended after the image (motion photos, MPF) does not matter.
    var i = 2;
    while (i < bytes.length - 1 &&
        !(bytes[i] == 0xFF && bytes[i + 1] == 0xDA)) {
      i++;
    }
    if (i >= bytes.length - 1) return false;
    for (i += 2; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) return true;
    }
    return false;
  }
  if (isPngBytes(bytes)) {
    // IEND chunk type followed by its 4-byte CRC ends the file.
    final from = bytes.length > 32 ? bytes.length - 32 : 0;
    for (var i = bytes.length - 4; i >= from; i--) {
      if (bytes[i] == 0x49 &&
          bytes[i + 1] == 0x45 &&
          bytes[i + 2] == 0x4E &&
          bytes[i + 3] == 0x44) {
        return true;
      }
    }
    return false;
  }
  if (isWebpBytes(bytes)) {
    final riffSize =
        bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
    return bytes.length >= riffSize + 8;
  }
  return true;
}
