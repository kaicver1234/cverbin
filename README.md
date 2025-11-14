# Tiksar VPN

A modern, feature-rich VPN client that's fast, unlimited, secure, and completely free.

## Features

- 🚀 Fast and unlimited VPN connection
- 🔒 Secure and encrypted traffic
- 🌍 Multiple server locations
- 📱 Android support
- 💻 Windows support (Desktop)
- 🎨 Beautiful and modern UI
- 🌐 Multi-language support (English, Persian)
- 🆓 Completely free and open source

## Platforms

### Android
- Full VPN functionality with TUN interface
- Background service support
- Auto-reconnect
- Split tunneling

### Windows (Desktop)
- **Proxy Mode**: System-wide proxy (Recommended)
- **VPN Mode**: Full system VPN (Requires Administrator)
- Modern desktop UI
- Real-time statistics
- Server selection

## Building for Windows

### Prerequisites
1. Flutter SDK (3.3.0 or higher)
2. Visual Studio 2022 with C++ desktop development
3. Windows 10/11

### Setup V2Ray Core (Required for Windows)

Before building the Windows app, you need to download V2Ray core:

#### Option 1: Automatic (Recommended)
```bash
# Run the download script
scripts\download_v2ray_core.bat
```

#### Option 2: Manual
1. Download V2Ray core from: https://github.com/v2fly/v2ray-core/releases/latest
2. Extract `v2ray-windows-64.zip`
3. Copy these files to `assets/v2ray-core/`:
   - `v2ray.exe`
   - `geoip.dat`
   - `geosite.dat`

### Build Commands

```bash
# Get dependencies
flutter pub get

# Build Windows release
flutter build windows --release

# Run in debug mode
flutter run -d windows
```

The built application will be in: `build\windows\runner\Release\`

## Building for Android

```bash
# Get dependencies
flutter pub get

# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

## Configuration

### Server Configuration
Servers are loaded from: `https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub.txt`

You can modify the server URL in `lib/services/server_service.dart`

### Windows VPN Mode
VPN Mode requires:
- Administrator privileges
- WinTun driver (future implementation)

For most users, **Proxy Mode** is recommended as it works without admin rights.

## Development

### Project Structure
```
lib/
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
├── services/        # Business logic
├── theme/           # App theming
├── utils/           # Utilities
└── widgets/         # Reusable widgets

assets/
├── images/          # App images
├── languages/       # Translations
└── v2ray-core/      # V2Ray binaries (Windows)
```

### Key Services
- `ServerService`: Fetches and parses server configurations
- `WindowsV2rayService`: Manages V2Ray core on Windows
- `WindowsProxyService`: Manages system proxy settings
- `WindowsTunService`: Manages VPN mode and admin rights

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

- Telegram: [@tiksar_vpn](https://t.me/tiksar_vpn)
- Instagram: [@aboljahany](https://instagram.com/aboljahany)
- Developer: Abol Jahany

## Acknowledgments

- [V2Ray](https://www.v2fly.org/) - Core VPN technology
- [Flutter](https://flutter.dev/) - UI framework
- All contributors and supporters

---

Made with ❤️ in Iran
