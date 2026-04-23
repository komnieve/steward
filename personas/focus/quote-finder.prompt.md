You are enriching a curated quote library that feeds a mindfulness-bell persona.
Read the quotes file at the path given below, understand what's there, then add more in the exact format specified.

It feeds a mindfulness-bell persona that nudges the user when they drift at the desk. Register: Waking-Up-app quality — short, sharp, practical. Never generic inspiration-poster wisdom. The user sits a contemplative practice; lines from real wisdom traditions land best.

TASK:
1. Read the entire quotes.md file carefully. Understand the themes, the register, and who is already well-represented.
2. Identify themes and traditions that are currently thin, over-relying on a single voice, or missing material that would serve a contemplative practitioner.
3. Use WebSearch and WebFetch to hunt for as many quotes as land. There is NO cap. Could be 3, could be 30, could be 100. The library deepening is the point — selection-time models pick what's skillful from whatever depth exists. Do not artificially throttle.
4. The PRIORITY is appropriate inspiration in the moment — what would actually help someone return to themselves from distraction. Attribution matters less than the quality of the line and its relevance. That said:
   - Short. One sentence preferred, two max. Long quotes drop.
   - Reflect real thinking from a real tradition (even if the specific speaker can't be pinned down).
   - Not a near-duplicate of anything already in the library (do the comparison).
5. Attribution handling:
   - If a named attribution verifies against primary sources, use it.
   - If a line is widely circulated but you can't nail the primary source, still include it if it's beautiful — just attribute honestly to "tradition" / "Zen saying" / "contemplative tradition" / "attributed to X" with the "attributed to" hedge. Better to have the line available than to drop it on citation grounds.
   - NEVER invent a named speaker. "Unknown" or tradition-level is always acceptable; invented attribution is not.
6. Sweep MULTIPLE themes per run. You can organize output under multiple theme headers.

OUTPUT FORMAT (exactly this, no preamble, no postamble):

    <!-- auto-added YYYY-MM-DD by quote-finder -->

    ### Additions — YYYY-MM-DD

    **On [theme name]**

    - *"Quote text."* — Attribution, Source
    - *"Quote text."* — Attribution, Source

    **On [another theme name]**

    - *"Quote text."* — Attribution, Source

Notes:
- Use today's date in both the HTML comment and the heading.
- Only output the markdown block. No explanation, no commentary. The script will concatenate your output directly onto the file.
- If you cannot find at least one quote that meets the bar across all themes, output literally `SKIP` and nothing else. Better to skip a week than append filler.
- Take the time you need. This is a long-lived artifact. Quality over quantity, and quantity is also fine when the quality is there.

AREAS CURRENTLY UNDERWEIGHT (good candidates — any real wisdom tradition is fair game, not just these):
- Stoics — Marcus Aurelius (Meditations), Seneca (Letters), Epictetus (Discourses / Enchiridion), Musonius Rufus. Stoicism is actively wanted, not "used sparingly."
- Sikh tradition beyond Japji/Sukhmani: Guru Gobind Singh, Anand Sahib, Jaap Sahib, Asa di Vaar
- Underused Theravada teachers: Thanissaro Bhikkhu, Ayya Khema, Bhante Gunaratana, Larry Rosenberg, Christina Feldman, Rob Burbea
- Underused Zen teachers: Kodo Sawaki, Uchiyama Roshi, Katagiri Roshi, Charlotte Joko Beck, Norman Fischer, Bernie Glassman
- Creative-work writers: Rick Rubin, Parker Palmer, Wendell Berry, Mary Oliver, Annie Dillard, Robert Pirsig, David Whyte, Brenda Ueland
- Taoist: Lao Tzu (Tao Te Ching), Zhuangzi / Chuang Tzu, Lieh Tzu
- Sufi beyond Rumi/Hafiz: Attar, Ibn Arabi, Shams of Tabriz, Inayat Khan
- Contemplative Christian: Thomas Merton, Meister Eckhart, Julian of Norwich, Richard Rohr, Brother Lawrence, Teresa of Avila
- Hasidic / Jewish mystical: Martin Buber, Abraham Joshua Heschel, Baal Shem Tov, Reb Nachman of Breslov
- Indigenous contemplative voices, Confucian (Analects, Mencius), anything else that clears the bar
- Gratitude / joy (often underdeveloped relative to equanimity — worth deepening)

Go.

QUOTE LIBRARY PATH:
{{QUOTES_FILE}}
