/// Natural alphanumeric sorting utility so "image_2.jpg" comes before "image_10.jpg".
class NaturalSort {
  static int compare(String a, String b) {
    final regex = RegExp(r'(\d+)|(\D+)');
    final aMatches = regex.allMatches(a.toLowerCase()).toList();
    final bMatches = regex.allMatches(b.toLowerCase()).toList();

    final minLength = aMatches.length < bMatches.length ? aMatches.length : bMatches.length;

    for (int i = 0; i < minLength; i++) {
      final aPart = aMatches[i].group(0)!;
      final bPart = bMatches[i].group(0)!;

      final aNum = int.tryParse(aPart);
      final bNum = int.tryParse(bPart);

      if (aNum != null && bNum != null) {
        final numComp = aNum.compareTo(bNum);
        if (numComp != 0) return numComp;
      } else {
        final strComp = aPart.compareTo(bPart);
        if (strComp != 0) return strComp;
      }
    }

    return aMatches.length.compareTo(bMatches.length);
  }
}
