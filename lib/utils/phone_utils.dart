class PhoneUtils {
  static bool arePhoneNumbersEqual(String phone1, String phone2) {
    // Remove all non-digit characters
    String cleanPhone1 = phone1.replaceAll(RegExp(r'\D'), '');
    String cleanPhone2 = phone2.replaceAll(RegExp(r'\D'), '');

    // If one number has a country code and the other doesn't,
    // compare the shorter one to the end of the longer one
    if (cleanPhone1.length != cleanPhone2.length) {
      String shorterNumber = cleanPhone1.length < cleanPhone2.length ? cleanPhone1 : cleanPhone2;
      String longerNumber = cleanPhone1.length > cleanPhone2.length ? cleanPhone1 : cleanPhone2;
      return longerNumber.endsWith(shorterNumber);
    }

    // If they're the same length, compare them directly
    return cleanPhone1 == cleanPhone2;
  }
}