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
  if (isJpegBytes(bytes)) return _jpegLooksComplete(bytes);
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

bool _jpegLooksComplete(List<int> bytes) {
  // Fast path: most files end with the end-of-image marker, possibly followed
  // by zero padding. Entropy-coded data cannot end in FF D9 by chance.
  var end = bytes.length;
  while (end > 4 && bytes.length - end < 64 && bytes[end - 1] == 0) {
    end--;
  }
  if (bytes[end - 2] == 0xFF && bytes[end - 1] == 0xD9) return true;
  // Data may follow the image (motion photos, MPF). Walk the marker segments
  // by their lengths, so an EXIF preview JPEG inside APP1 is skipped, up to
  // the main image's first start-of-scan; entropy-coded data cannot contain
  // FF D9, so a complete image has an end marker after it.
  var i = 2;
  while (i + 3 < bytes.length) {
    if (bytes[i] != 0xFF) return false;
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2; // standalone marker without a length
      continue;
    }
    if (marker == 0xDA) {
      for (var j = i + 2; j < bytes.length - 1; j++) {
        if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) return true;
      }
      return false;
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (length < 2) return false;
    i += 2 + length;
  }
  return false;
}
