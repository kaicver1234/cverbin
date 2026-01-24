#!/usr/bin/env python3
"""
Icon Generator for TiksarVPN
Generates all required icon sizes from source image
"""

from PIL import Image
import os

def generate_launcher_icons():
    """Generate launcher icons in all required sizes"""
    
    # Source image
    source = "assets/images/apk.png"
    
    if not os.path.exists(source):
        print(f"❌ Error: {source} not found!")
        return
    
    # Open source image
    img = Image.open(source)
    print(f"✓ Loaded source image: {img.size}")
    
    # Launcher icon sizes
    sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192
    }
    
    # Generate icons
    for folder, size in sizes.items():
        # Create output path
        output_dir = f"android/app/src/main/res/{folder}"
        os.makedirs(output_dir, exist_ok=True)
        output_path = f"{output_dir}/ic_launcher.png"
        
        # Resize and save
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_path, 'PNG')
        print(f"✓ Created {output_path} ({size}x{size})")
    
    print("\n✅ All launcher icons generated successfully!")

def generate_adaptive_icons():
    """Generate adaptive launcher icons (foreground)"""
    
    source = "assets/images/apk.png"
    
    if not os.path.exists(source):
        print(f"❌ Error: {source} not found!")
        return
    
    # Open source image
    img = Image.open(source)
    
    # Adaptive icon sizes (foreground)
    sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432
    }
    
    # Generate adaptive foreground icons
    for folder, size in sizes.items():
        output_dir = f"android/app/src/main/res/{folder}"
        os.makedirs(output_dir, exist_ok=True)
        output_path = f"{output_dir}/ic_launcher_foreground.png"
        
        # Resize and save
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_path, 'PNG')
        print(f"✓ Created {output_path} ({size}x{size})")
    
    print("\n✅ All adaptive icons generated successfully!")

def generate_notification_icon():
    """Generate notification icon from notif.png"""
    
    source = "assets/images/notif.png"
    
    if not os.path.exists(source):
        print(f"❌ Error: {source} not found!")
        print("Please upload notif.png to assets/images/ folder")
        return
    
    # Open source image
    img = Image.open(source).convert('RGBA')
    print(f"✓ Loaded notification source: {img.size}")
    
    # Notification icon sizes for different densities
    sizes = {
        'drawable-mdpi': 24,
        'drawable-hdpi': 36,
        'drawable-xhdpi': 48,
        'drawable-xxhdpi': 72,
        'drawable-xxxhdpi': 96
    }
    
    # Generate notification icons
    for folder, size in sizes.items():
        output_dir = f"android/app/src/main/res/{folder}"
        os.makedirs(output_dir, exist_ok=True)
        output_path = f"{output_dir}/ic_notification.png"
        
        # Resize and save
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_path, 'PNG')
        print(f"✓ Created {output_path} ({size}x{size})")
    
    print("\n✅ Notification icon generated successfully!")

if __name__ == "__main__":
    print("🎨 TiksarVPN Icon Generator\n")
    print("=" * 50)
    
    # Generate launcher icons
    print("\n📱 Generating Launcher Icons...")
    generate_launcher_icons()
    
    # Generate adaptive icons
    print("\n🎯 Generating Adaptive Icons...")
    generate_adaptive_icons()
    
    # Generate notification icon
    print("\n🔔 Generating Notification Icon...")
    generate_notification_icon()
    
    print("\n" + "=" * 50)
    print("✅ All icons generated!")
    print("\nNext steps:")
    print("1. Run: flutter clean")
    print("2. Run: flutter build apk --release")
