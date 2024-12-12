#!/usr/bin/python3
#public
import random
import sys

def main():
    # Randomly choose an exit code with 50% probability for 0
    exit_code = random.choices([0, 1, 2, 3], weights=[0.5, 0.1667, 0.1667, 0.1667])[0]
    
    # Print the exit code and status message
    if exit_code == 0:
        print(f"Exit Code: {exit_code} - Resolved")
    else:
        print(f"Exit Code: {exit_code} - Failed")
    
    # Print some Lorem Ipsum text
    print("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
    print("Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
    print("Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
    print("Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.")
    
    # Exit with the chosen code
    sys.exit(exit_code)

if __name__ == "__main__":
    main()