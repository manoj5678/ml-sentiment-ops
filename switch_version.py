#!/usr/bin/env python3
import sys
import shutil

if len(sys.argv) != 2 or sys.argv[1] not in ['simple', 'full']:
    print("Usage: python switch_version.py [simple|full]")
    print("  simple - Use mock version (no ML libraries)")
    print("  full   - Use full version (requires PyTorch/Transformers)")
    sys.exit(1)

version = sys.argv[1]

if version == 'simple':
    print("🔄 Switching to simple version (mock model)...")
    shutil.copy('src/api/main_simple.py', 'src/api/main.py')
    shutil.copy('src/monitoring/metrics_simple.py', 'src/monitoring/metrics.py')
    shutil.copy('Dockerfile.simple', 'Dockerfile')
    print("✅ Now using simple version - no ML libraries required")
else:
    print("🔄 Switching to full version (real ML model)...")
    print("⚠️  Make sure PyTorch and Transformers are installed!")
    # Copy full versions (you'll create these when environment is fixed)
    print("❌ Full version files not yet created")

print(f"\n📌 Next steps:")
print(f"1. Run locally: python -m src.api.main")
print(f"2. Run with Docker: docker-compose -f docker-compose.simple.yml up")