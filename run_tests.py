import sys
import unittest

# The environment may lack lupa, but existing scripts rely on importing it.
# We skip the test gracefully if it's not available to improve code health
# and prevent stack traces, unless the exact behavior of ImportError was required.
# However, standard unittest behavior for missing deps is to skip.
try:
    from lupa import LuaRuntime
    LUPA_AVAILABLE = True
except ImportError:
    LUPA_AVAILABLE = False


class LuaTestRunner(unittest.TestCase):
    test_file = None

    def setUp(self):
        if not LUPA_AVAILABLE:
            self.skipTest("lupa module not available, cannot run Lua tests in Python")

        if not self.test_file:
            self.skipTest("No test file provided")

    def test_run_lua_script(self):
        lua = LuaRuntime()

        def dofile(filename):
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

        try:
            dofile(self.test_file)
        except SystemExit as e:
            if e.code != 0:
                self.fail(f"Test exited with code {e.code}")
        except Exception as e:
            # Check if it's a Lua error wrapping SystemExit or similar
            self.fail(f"Test failed with exception: {e}")

if __name__ == "__main__":
    test_file = None
    # Extract the test file argument which is not a flag
    for i, arg in enumerate(sys.argv[1:], 1):
        if not arg.startswith('-'):
            test_file = sys.argv.pop(i)
            break

    if not test_file:
        print("Usage: python3 run_tests.py [unittest_args...] <test_file>")
        sys.exit(1)

    LuaTestRunner.test_file = test_file
    unittest.main()
