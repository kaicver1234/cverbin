# فرمت قرار دادن سرورها در GitHub

## فرمت جدید (با پرچم):

هر خط باید به این صورت باشد:
```
[COUNTRY_CODE] SERVER_CONFIG
```

### مثال‌ها:

```
[DE] vless://uuid@server.com:443?encryption=none&security=tls&sni=server.com&type=ws&host=server.com&path=/path#Germany-1
[US] vmess://eyJ2IjoiMiIsInBzIjoiVVMtMSIsImFkZCI6InVzLnNlcnZlci5jb20iLCJwb3J0IjoiNDQzIiwiaWQiOiJ1dWlkIiwiYWlkIjoiMCIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoidXMuc2VydmVyLmNvbSIsInBhdGgiOiIvcGF0aCIsInRscyI6InRscyJ9
[FR] vless://uuid@fr.server.com:443?encryption=none&security=tls&sni=fr.server.com&type=ws#France-1
[GB] ss://method:password@uk.server.com:443#UK-1
[NL] trojan://password@nl.server.com:443?security=tls&sni=nl.server.com&type=tcp#Netherlands-1
[CA] vless://uuid@ca.server.com:443?encryption=none&security=tls#Canada-1
[JP] vmess://base64config#Japan-1
[SG] vless://uuid@sg.server.com:443?encryption=none&security=tls#Singapore-1
```

## کدهای کشور (ISO 3166-1 alpha-2):

### اروپا (Europe):
- 🇩🇪 DE = آلمان (Germany)
- 🇫🇷 FR = فرانسه (France)
- 🇬🇧 GB = انگلستان (United Kingdom)
- 🇳🇱 NL = هلند (Netherlands)
- 🇸🇪 SE = سوئد (Sweden)
- 🇫🇮 FI = فنلاند (Finland)
- 🇵🇱 PL = لهستان (Poland)
- 🇮🇹 IT = ایتالیا (Italy)
- 🇪🇸 ES = اسپانیا (Spain)
- 🇨🇭 CH = سوئیس (Switzerland)
- 🇦🇹 AT = اتریش (Austria)
- 🇧🇪 BE = بلژیک (Belgium)
- 🇩🇰 DK = دانمارک (Denmark)
- 🇳🇴 NO = نروژ (Norway)
- 🇮🇪 IE = ایرلند (Ireland)
- 🇵🇹 PT = پرتغال (Portugal)
- 🇬🇷 GR = یونان (Greece)
- 🇨🇿 CZ = جمهوری چک (Czech Republic)
- 🇷🇴 RO = رومانی (Romania)
- 🇭🇺 HU = مجارستان (Hungary)
- 🇧🇬 BG = بلغارستان (Bulgaria)
- 🇸🇰 SK = اسلواکی (Slovakia)
- 🇭🇷 HR = کرواسی (Croatia)
- 🇺🇦 UA = اوکراین (Ukraine)
- 🇷🇸 RS = صربستان (Serbia)

### آمریکا (Americas):
- 🇺🇸 US = آمریکا (United States)
- 🇨🇦 CA = کانادا (Canada)
- 🇲🇽 MX = مکزیک (Mexico)
- 🇧🇷 BR = برزیل (Brazil)
- 🇦🇷 AR = آرژانتین (Argentina)
- 🇨🇱 CL = شیلی (Chile)
- 🇨🇴 CO = کلمبیا (Colombia)
- 🇵🇪 PE = پرو (Peru)

### آسیا (Asia):
- 🇯🇵 JP = ژاپن (Japan)
- 🇸🇬 SG = سنگاپور (Singapore)
- 🇭🇰 HK = هنگ کنگ (Hong Kong)
- 🇰🇷 KR = کره جنوبی (South Korea)
- 🇹🇼 TW = تایوان (Taiwan)
- 🇮🇳 IN = هند (India)
- 🇨🇳 CN = چین (China)
- 🇹🇭 TH = تایلند (Thailand)
- 🇲🇾 MY = مالزی (Malaysia)
- 🇮🇩 ID = اندونزی (Indonesia)
- 🇵🇭 PH = فیلیپین (Philippines)
- 🇻🇳 VN = ویتنام (Vietnam)
- 🇰🇭 KH = کامبوج (Cambodia)
- 🇵🇰 PK = پاکستان (Pakistan)
- 🇧🇩 BD = بنگلادش (Bangladesh)
- 🇰🇿 KZ = قزاقستان (Kazakhstan)

### خاورمیانه (Middle East):
- 🇹🇷 TR = ترکیه (Turkey)
- 🇦🇪 AE = امارات (UAE)
- 🇸🇦 SA = عربستان (Saudi Arabia)
- 🇮🇱 IL = اسرائیل (Israel)
- 🇮🇶 IQ = عراق (Iraq)
- 🇮🇷 IR = ایران (Iran)
- 🇯🇴 JO = اردن (Jordan)
- 🇱🇧 LB = لبنان (Lebanon)
- 🇴🇲 OM = عمان (Oman)
- 🇰🇼 KW = کویت (Kuwait)
- 🇧🇭 BH = بحرین (Bahrain)
- 🇶🇦 QA = قطر (Qatar)
- 🇦🇲 AM = ارمنستان (Armenia)
- 🇦🇿 AZ = آذربایجان (Azerbaijan)
- 🇬🇪 GE = گرجستان (Georgia)

### اقیانوسیه (Oceania):
- 🇦🇺 AU = استرالیا (Australia)
- 🇳🇿 NZ = نیوزلند (New Zealand)
- 🇫🇯 FJ = فیجی (Fiji)

### آفریقا (Africa):
- 🇿🇦 ZA = آفریقای جنوبی (South Africa)
- 🇪🇬 EG = مصر (Egypt)
- 🇳🇬 NG = نیجریه (Nigeria)
- 🇰🇪 KE = کنیا (Kenya)
- 🇲🇦 MA = مراکش (Morocco)
- 🇹🇳 TN = تونس (Tunisia)
- 🇩🇿 DZ = الجزایر (Algeria)
- 🇱🇾 LY = لیبی (Libya)
- 🇪🇹 ET = اتیوپی (Ethiopia)
- 🇬🇭 GH = غنا (Ghana)

## نکات مهم:

1. کد کشور باید داخل براکت `[]` باشد
2. بعد از براکت یک فاصله بگذارید
3. سپس کانفیگ کامل سرور را بنویسید
4. هر سرور در یک خط جداگانه
5. اگر کد کشور نداشته باشید، سرور بدون پرچم نمایش داده می‌شود

## مثال فایل کامل در GitHub:

```
[DE] vless://uuid1@de1.server.com:443?encryption=none&security=tls&sni=de1.server.com&type=ws&host=de1.server.com&path=/ws#Germany-1
[DE] vless://uuid2@de2.server.com:443?encryption=none&security=tls&sni=de2.server.com&type=ws&host=de2.server.com&path=/ws#Germany-2
[US] vmess://config1#USA-1
[US] vmess://config2#USA-2
[FR] vless://uuid3@fr.server.com:443?encryption=none&security=tls#France-1
[GB] ss://method:password@uk.server.com:443#UK-1
[NL] trojan://password@nl.server.com:443?security=tls#Netherlands-1
[CA] vless://uuid4@ca.server.com:443?encryption=none&security=tls#Canada-1
[JP] vless://uuid5@jp.server.com:443?encryption=none&security=tls#Japan-1
[SG] vless://uuid6@sg.server.com:443?encryption=none&security=tls#Singapore-1
```

## لینک GitHub شما:

فایل را در این مسیر قرار دهید:
```
https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/servers.txt
```

مثال:
```
https://raw.githubusercontent.com/tiksarvpn/servers/main/servers.txt
```
