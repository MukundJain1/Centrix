/// A country with its dial code. The flag is built from the ISO code,
/// so no emoji or image assets need to be stored.
class Country {
  const Country(this.name, this.iso, this.dialCode);

  final String name;

  /// ISO 3166-1 alpha-2 code, e.g. "IN". Used as the unique id, because
  /// several countries share a dial code (US and CA both use +1).
  final String iso;

  /// Dial code including the plus sign, e.g. "+91".
  final String dialCode;

  /// Flag emoji built from the ISO code.
  String get flag => String.fromCharCodes(
        iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );

  /// Max digits allowed in the national number.
  int get maxPhoneDigits => iso == 'IN' ? 10 : 15;

  static const Country india = Country('India', 'IN', '+91');

  static Country? byIso(String? iso) {
    if (iso == null) return null;
    for (final c in all) {
      if (c.iso == iso) return c;
    }
    return null;
  }

  static const List<Country> all = [
    india,
    Country('United States', 'US', '+1'),
    Country('United Kingdom', 'GB', '+44'),
    Country('Canada', 'CA', '+1'),
    Country('Australia', 'AU', '+61'),
    Country('United Arab Emirates', 'AE', '+971'),
    Country('Saudi Arabia', 'SA', '+966'),
    Country('Qatar', 'QA', '+974'),
    Country('Kuwait', 'KW', '+965'),
    Country('Oman', 'OM', '+968'),
    Country('Bahrain', 'BH', '+973'),
    Country('Singapore', 'SG', '+65'),
    Country('Malaysia', 'MY', '+60'),
    Country('Indonesia', 'ID', '+62'),
    Country('Thailand', 'TH', '+66'),
    Country('Philippines', 'PH', '+63'),
    Country('Vietnam', 'VN', '+84'),
    Country('Japan', 'JP', '+81'),
    Country('South Korea', 'KR', '+82'),
    Country('China', 'CN', '+86'),
    Country('Hong Kong', 'HK', '+852'),
    Country('Taiwan', 'TW', '+886'),
    Country('Pakistan', 'PK', '+92'),
    Country('Bangladesh', 'BD', '+880'),
    Country('Sri Lanka', 'LK', '+94'),
    Country('Nepal', 'NP', '+977'),
    Country('Bhutan', 'BT', '+975'),
    Country('Maldives', 'MV', '+960'),
    Country('Afghanistan', 'AF', '+93'),
    Country('Iran', 'IR', '+98'),
    Country('Iraq', 'IQ', '+964'),
    Country('Israel', 'IL', '+972'),
    Country('Turkey', 'TR', '+90'),
    Country('Egypt', 'EG', '+20'),
    Country('South Africa', 'ZA', '+27'),
    Country('Nigeria', 'NG', '+234'),
    Country('Kenya', 'KE', '+254'),
    Country('Ghana', 'GH', '+233'),
    Country('Ethiopia', 'ET', '+251'),
    Country('Mauritius', 'MU', '+230'),
    Country('Germany', 'DE', '+49'),
    Country('France', 'FR', '+33'),
    Country('Italy', 'IT', '+39'),
    Country('Spain', 'ES', '+34'),
    Country('Portugal', 'PT', '+351'),
    Country('Netherlands', 'NL', '+31'),
    Country('Belgium', 'BE', '+32'),
    Country('Switzerland', 'CH', '+41'),
    Country('Austria', 'AT', '+43'),
    Country('Sweden', 'SE', '+46'),
    Country('Norway', 'NO', '+47'),
    Country('Denmark', 'DK', '+45'),
    Country('Finland', 'FI', '+358'),
    Country('Ireland', 'IE', '+353'),
    Country('Poland', 'PL', '+48'),
    Country('Russia', 'RU', '+7'),
    Country('Ukraine', 'UA', '+380'),
    Country('Greece', 'GR', '+30'),
    Country('New Zealand', 'NZ', '+64'),
    Country('Fiji', 'FJ', '+679'),
    Country('Brazil', 'BR', '+55'),
    Country('Mexico', 'MX', '+52'),
    Country('Argentina', 'AR', '+54'),
    Country('Chile', 'CL', '+56'),
    Country('Colombia', 'CO', '+57'),
    Country('Peru', 'PE', '+51'),
  ];
}
