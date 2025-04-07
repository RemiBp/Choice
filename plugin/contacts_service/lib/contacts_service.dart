class Contact {
  Contact({
    this.displayName,
    this.givenName,
    this.middleName,
    this.prefix,
    this.suffix,
    this.familyName,
    this.company,
    this.jobTitle,
    this.emails = const [],
    this.phones = const [],
    this.postalAddresses = const [],
    this.avatar,
    this.birthday,
    this.androidAccountTypeRaw,
    this.androidAccountName,
    this.identifier,
  });

  String? identifier;
  String? displayName;
  String? givenName;
  String? middleName;
  String? prefix;
  String? suffix;
  String? familyName;
  String? company;
  String? jobTitle;
  List<Item> emails = [];
  List<Item> phones = [];
  List<PostalAddress> postalAddresses = [];
  Uint8List? avatar;
  DateTime? birthday;
  String? androidAccountTypeRaw;
  String? androidAccountName;

  String? androidAccountType() {
    if (androidAccountTypeRaw == null) return null;
    if (androidAccountTypeRaw == "com.google") return "google";
    if (androidAccountTypeRaw == "com.whatsapp")
      return "whatsapp";
    return null;
  }

  Contact.fromMap(Map<dynamic, dynamic> m) {
    displayName = m["displayName"];
    givenName = m["givenName"];
    middleName = m["middleName"];
    prefix = m["prefix"];
    suffix = m["suffix"];
    familyName = m["familyName"];
    company = m["company"];
    jobTitle = m["jobTitle"];

    emails = (m["emails"] as List?)
            ?.map((item) => Item.fromMap(item))
            .toList() ??
        [];
    phones = (m["phones"] as List?)
            ?.map((item) => Item.fromMap(item))
            .toList() ??
        [];
    postalAddresses = (m["postalAddresses"] as List?)
            ?.map((item) => PostalAddress.fromMap(item))
            .toList() ??
        [];

    avatar = m["avatar"];
    try {
      birthday = DateTime.parse(m["birthday"]);
    } catch (e) {
      birthday = null;
    }

    androidAccountTypeRaw = m["androidAccountType"];
    androidAccountName = m["androidAccountName"];
    identifier = m["identifier"];
  }
} 