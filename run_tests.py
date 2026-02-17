import sys
import os
from lupa import LuaRuntime

def run_test(test_file):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def dofile(filename):
        # Resolve path relative to CWD
        if not os.path.exists(filename):
            print(f"Error: File not found: {filename}")
            raise FileNotFoundError(filename)

        with open(filename, 'r') as f:
            code = f.read()

        # Execute and return result
        try:
            return lua.execute(code)
        except Exception as e:
            print(f"Error executing {filename}: {e}")
            raise e

    # Inject dofile into global environment
    lua.globals().dofile = dofile

    # Inject basic OS facilities if needed, but mock_roblox mocks most things.
    # However, existing tests rely on os.exit() which lupa might not handle gracefully
    # if it calls C exit. Lua's os.exit usually terminates the process.
    # Lupa might catch SystemExit?

    print(f"Running {test_file}...")
    try:
        dofile(test_file)
    except SystemExit as e:
        if e.code != 0:
            print(f"Test exited with code {e.code}")
            sys.exit(e.code)
    except Exception as e:
        # Check if it's a Lua error wrapping SystemExit or similar
        print(f"Test failed with exception: {e}")
        sys.exit(1)

    print("Test execution finished.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 run_tests.py <test_file>")
        sys.exit(1)

    run_test(sys.argv[1])
