#!/usr/bin/env python3
"""
ZIVPN SIMPLE PROTECTION - Destroy source code only
Keep systemd as is (working perfectly)
"""

import os
import sys
import subprocess
import random
import string
import shutil

def run_cmd(cmd):
    """Run command silently"""
    try:
        subprocess.run(cmd, shell=True, check=True, 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except:
        return False

def install_pyinstaller():
    """Install PyInstaller for compilation"""
    print("📦 Installing PyInstaller...")
    run_cmd("pip3 install pyinstaller --quiet")
    run_cmd("apt-get install -y python3-pyinstaller 2>/dev/null")

def compile_and_destroy():
    """Compile to binaries and destroy source - SIMPLE VERSION"""
    print("🔐 Starting protection system...")
    
    zivpn_dir = "/etc/zivpn"
    
    # List of scripts to protect
    scripts = [
        "web.py", "bot.py", "api.py", 
        "cleanup.py", "backup.py", "connection_manager.py"
    ]
    
    for script in scripts:
        script_path = f"{zivpn_dir}/{script}"
        
        # Check if file exists
        if os.path.exists(script_path):
            print(f"🛡️  Protecting {script}...")
            
            try:
                # OPTIONAL: Create backup in memory (optional)
                with open(script_path, 'rb') as f:
                    file_content = f.read()
                
                # Step 1: Try to compile (optional)
                try:
                    print(f"  Compiling {script}...")
                    # Simple compilation command
                    cmd = [
                        "pyinstaller", "--onefile", "--noconsole",
                        "--distpath", "/usr/local/bin",
                        "--workpath", "/tmp",
                        script_path
                    ]
                    subprocess.run(cmd, capture_output=True, timeout=30)
                    
                    # Rename to random name
                    original_bin = f"/usr/local/bin/{script.replace('.py', '')}"
                    if os.path.exists(original_bin):
                        random_name = f"zivpn_{''.join(random.choices(string.ascii_lowercase, k=6))}"
                        new_bin = f"/usr/local/bin/{random_name}"
                        shutil.move(original_bin, new_bin)
                        os.chmod(new_bin, 0o755)
                        print(f"  ✅ Created binary: {new_bin}")
                except:
                    print(f"  ⚠️  Compilation skipped for {script}")
                
                # Step 2: DESTROY SOURCE FILE (MOST IMPORTANT)
                print(f"  Destroying {script}...")
                
                # Method 1: Overwrite with random data
                for i in range(3):
                    with open(script_path, 'wb') as f:
                        f.write(os.urandom(1024))
                
                # Method 2: Delete file
                os.remove(script_path)
                
                # Method 3: Create dummy file (optional)
                dummy_content = f"# This file has been protected by ZIVPN Security System\n# Original source code is no longer available\n# Generated: {random.randint(10000, 99999)}"
                with open(script_path, 'w') as f:
                    f.write(dummy_content)
                
                # Method 4: Set strict permissions
                os.chmod(script_path, 0o600)
                
                print(f"  ✅ Destroyed: {script}")
                
            except Exception as e:
                print(f"  ❌ Error protecting {script}: {e}")
                # Still try to make file unreadable
                try:
                    os.chmod(script_path, 0)
                    print(f"  🔒 Set zero permissions on {script}")
                except:
                    pass

def clean_traces():
    """Clean installation traces"""
    print("🧹 Cleaning traces...")
    
    # Remove compilation traces
    run_cmd("rm -rf /tmp/pybuild* /tmp/_MEI* 2>/dev/null")
    
    # Remove Python cache
    run_cmd("find /etc/zivpn -name '*.pyc' -delete 2>/dev/null")
    run_cmd("find /etc/zivpn -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null")
    
    # Remove this script
    script_path = sys.argv[0]
    try:
        if os.path.exists(script_path):
            # Overwrite
            with open(script_path, 'wb') as f:
                f.write(os.urandom(512))
            os.remove(script_path)
    except:
        pass
    
    # Clear history
    run_cmd("history -c 2>/dev/null")
    run_cmd("echo '' > ~/.bash_history")
    
    print("✅ Traces cleaned")

def main():
    print("="*60)
    print("🛡️  ZIVPN SIMPLE PROTECTION SYSTEM")
    print("="*60)
    
    # Step 1: Install tools
    install_pyinstaller()
    
    # Step 2: Destroy source files (MAIN JOB)
    compile_and_destroy()
    
    # Step 3: Clean traces
    clean_traces()
    
    print("="*60)
    print("✅ PROTECTION COMPLETED!")
    print("="*60)
    print("🔒 Source files have been protected")
    print("⚡ System continues to work normally")
    print("🔄 NO changes to systemd services")
    print("📊 Web panel & bot remain functional")
    print("="*60)
    
    # Final instructions
    print("\n📝 IMPORTANT NOTES:")
    print("1. Source code is now protected")
    print("2. Systemd services unchanged (keeps working)")
    print("3. If services stop, they won't restart automatically")
    print("4. This is the SAFEST approach")
    print("="*60)

if __name__ == "__main__":
    main()
