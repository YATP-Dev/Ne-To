# Short-word frequency data

`Sources/NeTo/ShortWordFrequency.swift` contains ranks for two-letter English and Russian words. These ranks are separate data from Ne-To's MIT-licensed code. They are derived from:

- English: [PAndaContron/EnglishWordFrequencies](https://github.com/PAndaContron/EnglishWordFrequencies/tree/1224f466fbcd79eaf07fab51b271495f8fa6a4ed), which processes Google Books 1-gram counts. The source data is licensed [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). Words were sorted by count and assigned ranks; only two-letter entries in the top 10,000 were retained.
- Russian: [hingston/russian](https://github.com/hingston/russian/tree/b144235f90fc720ef310f304e31acc3825d62a1b), derived from the University of Leeds Corpus and distributed under [CC BY 2.5](https://creativecommons.org/licenses/by/2.5/). Only two-letter entries from its ranked top 10,000 Cyrillic word list were retained.

The ranks are used offline only. The app never downloads a dictionary or uploads typed text.
