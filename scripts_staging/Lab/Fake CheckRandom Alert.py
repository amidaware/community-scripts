#!/usr/bin/python3
import random
import sys
import io
import json
#public

# Ensure the standard output is set to UTF-8 encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Utility function to handle safe printing of Unicode
def safe_print(s):
    try:
        print(s)
    except UnicodeEncodeError:
        # Replace unprintable characters with replacement character
        print(s.encode('utf-8', 'replace').decode('utf-8'))

# Define problematic strings and edge cases
unicode_tests = [
    # Unicode and Special Cases
    "Unicode test: \U0001D11E\u266B",  # Musical symbol and note
    "Contains special chars: !@#$%^&*()_+|}{:\"?><,./;'[]\\=-`~",
    "Embedded newlines\nshould be handled",
    "Embedded quotes \"double\" and 'single' quotes",
    "JSON breaking chars: {}[]:,",
    "Non-printable characters: \x1B \x07 \x00",
    "Backslashes \\ and forward slashes /",
    "Tab characters\t should be included",
    "Carriage return\r characters",
    "Mixed escape sequences \n \r \t \b \f",
    "Control characters: " + "".join(chr(i) for i in range(32)),
    "Combining characters: a\u0301 e\u0301 i\u0301 o\u0301 u\u0301",  # á é í ó ú
    "Right-to-left text: \u202Ethis text is rtl",
    "Null character: \x00 in the middle",
    "Special Unicode: \uFFFF \uFFFE",
    "Mathematical symbols: ∑∏∫∬∭",
    "Currency symbols: ¢£¤¥",
    "Different spaces: \u2000 \u2001 \u2002 \u2003",
    "Zero-width spaces: \u200B\u200C\u200D\uFEFF",
    "Emoji sequence: 🧩🧪🧫",
    "Surrogate pairs: \U0001F600\U0001F606",  # 😀😆
    "Large code points: \U0002A7D4 \U0001F6D0",  # Mathematical Operators, Shield
    "Math symbols: ∆√∛∞",
    "Text direction: \u061C\u202D\u202C",
    "High surrogate: \uD83D\uDE00",  # 😀
    "Low surrogate: \uDE00",  # Low surrogate to pair with high surrogate
    "Complex sequences: \uD83C\uDF1F\uD83C\uDF1F\uD83C\uDF1F",  # Multiple Sun Symbols
    "Combining diacritics: \u0041\u030A\u0042\u0308\u0043\u0327",  # Å B̈ Ç
    "Zero-width joiners: \u200D\u200D\u200D",  # Zero-width joiner repetition
    "Double-byte characters: \u4F60\u597D\uFF0C\u4E16\u754C",  # Chinese characters

    # Escaping Characters
    "Escaping quotes: \"\" \"'\" \\'",
 #   "Escaping backslashes: \\\\ \\\\ \\\\\\\\\\\",
    "Escaping newlines: Line1\\nLine2",
    "Escaping carriage returns: Line1\\rLine2",

    # Extremely Large Strings
    "Extremely large string: " + "x" * 10000,
    "Extremely large multiline string:\n" + "\n".join(["This is a test line."] * 500),

    # Additional Special Characters
    "Rare symbols: ⧫ ⍟ ⎈ ⍾ ⏚",
    "Technical symbols: ⌘ ⌥ ⌫ ⌦ ⎋",
    "Mathematical operators: ⊥ ⊗ ⊙ ⊚ ⊻",

    # More Languages and Scripts
    "Armenian: բարև աշխարհ",  # Hello, World
    "Bengali: হ্যালো বিশ্ব",  # Hello, World
    "Georgian: გამარჯობა მსოფლიო",  # Hello, World
    "Gujarati: નમસ્તે વિશ્વ",  # Hello, World
    "Hmong: Nyob zoo ntiaj teb",  # Hello, World
    "Javanese: Halo Dunia",  # Hello, World
    "Kannada: ನಮಸ್ಕಾರ ಜಗತ್ತಿಗೆ",  # Hello, World
    "Lao: ສະບາຍດີໂລກ",  # Hello, World
    "Malayalam: ഹലോ ലോകം",  # Hello, World
    "Myanmar: မင်္ဂလာပါ ကမ္ဘာလောက",  # Hello, World
    "Nepali: नमस्कार संसार",  # Hello, World
    "Sinhala: හෙලෝ ලෝකය",  # Hello, World
    "Tamil: வணக்கம் உலகம்",  # Hello, World
    "Telugu: హలో వరల్డ్",  # Hello, World
    "Tibetan: བཀྲིས་གནང་བརྗེད་",  # Hello, World
    "Uzbek: Salom Dunyo",  # Hello, World

    # Extreme Unicode Edge Cases
    "Extremely high Unicode: \U0010FFFF",  # Highest code point in Unicode
    "Extremely low Unicode: \u0001",  # Lowest code point in Unicode
    "Middle of Unicode range: \U00010000",  # Supplementary Planes

    # Text Layout and Formatting
    "Bidirectional text: \u05D0\u05D1\u05D2\u200F\u202E\u05D3\u05D4\u05D5",  # Hebrew text with RTL overrides
    "Zalgo text: H̵e̸l̷l̶o̴ W̵o̸r̷l̶d̴",  # Zalgo effect
    "Invisible characters: \u200B\u200C\u200D\uFEFF",  # Invisible characters in between

    # Complex Combining Sequences
    "Multiple combining diacritics: a\u0300\u0301\u0302\u0303\u0304\u0305",  # Combining diacritics over a base character
    "Overlapping combining characters: a\u0336\u0336\u0336\u0336",  # Multiple strikethroughs

    # Additional Complex Cases
    "Surrogates edge cases: \uD83D\uDE00\uD83D\uDE01\uD83D\uDE02\uD83D\uDE03",  # Multiple emojis
    "Mirrored text: \u0623\u0646\u0633\u0627\u0646",  # Arabic script (human)
    "Vowel diacritics: a\u0316\u0317\u0318\u0319\u031A",  # Various vowel diacritics
    "Overlap text: ᎣᏢᏯᏪᏮ",  # Cherokee text
    "Long text with mixed scripts: 你好, こんにちは, 안녕하세요, Hello!",  # Multiple scripts
    "Emoji with skin tones: 👋🏻👋🏼👋🏽👋🏾👋🏿",  # Wave emoji with skin tones
    "Complex formatting: \u2063\u2064\u2065\u2066",  # Invisible and non-visible formatting characters
    "Extremely high code point combined with low: \u0001\U0010FFFF",  # Low and high code points combined
    "Languages with various punctuation: ÀÀÀÀ àààà ¡Hola! ¿Cómo estás?",  # Punctuation and accents

    # SQL Injection and Special Characters
    "Basic SQL Injection: ' OR '1'='1",
    "SQL Injection with comment: '; DROP TABLE users;--",
    "SQL Injection with nested query: ' UNION SELECT null, username, password FROM users--",
    "SQL Injection with hex encoding: 0x27 UNION SELECT null, username, password FROM users--",
    "SQL Injection with multiple queries: ' ; SELECT * FROM users;--",
    "SQL Injection with special characters: ' OR 1=1; --",
    "SQL Injection with Unicode: ' OR 1=1 -- 𝒜𝒷𝒸",
    "SQL Injection with long payload: " + "a" * 10000,

    # PostgreSQL Specific Cases
    "PostgreSQL large string: " + "a" * 10000,
    "PostgreSQL special chars: \u00A9 \u00AE \u20AC",
    "PostgreSQL JSON injection: {\"key\": \"value\", \"test\": 1}",
    "PostgreSQL JSON special chars: {\"key\": \"value\\nwith\\nnewlines\", \"test\": 1}",
    "PostgreSQL complex JSON: {\"key\": {\"subkey\": [1, 2, 3], \"otherkey\": true}}",
    "PostgreSQL JSON with Unicode: {\"key\": \"value\", \"emoji\": \"\U0001F600\"}",
    "PostgreSQL JSON with SQL Injection: {\"key\": \"value' OR '1'='1\"}",
]

# Randomly set the exit code to 1 or 2
exit_code = random.choice([1, 2])

# Print out the Unicode test strings
for test in unicode_tests:
    safe_print(test)

# Output the exit code to a JSON file
output = {"exit_code": exit_code}

with open("output.json", "w", encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False)

# Exit with the chosen code
sys.exit(exit_code)