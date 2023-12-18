# Dan Q's FreshRSS->OPML Extractor

Used to generate content used by https://danq.me/blogroll.

Probably no use to anybody else whatsoever.

## Setup

Add a table to your FreshRSS DB like this, and use it to map category names from FreshRSS (`in`) to your preferred ones (`out`). Specify an ordering if you like. Unspecified ones go to the bottom. `out` is secondary sort:

```sql
CREATE TABLE `danq_category_export_mappings` (
  `in` VARCHAR(191) NOT NULL COLLATE 'utf8mb4_unicode_ci',
  `out` VARCHAR(191) NOT NULL COLLATE 'utf8mb4_unicode_ci',
  `description` TEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
  `order` TINYINT(3) NULL DEFAULT NULL,
  PRIMARY KEY (`in`) USING BTREE
)
COLLATE='utf8mb4_0900_ai_ci'
ENGINE=InnoDB
;
```

## Usage

Create a `.env` or otherwise set environment variables. E.g.

```bash
FRESHRSS_HOST=fox
FRESHRSS_DB=freshrss
FRESHRSS_USER=
FRESHRSS_PASSWORD=

DANQ_SSH_PORT=
DANQ_HOST=
DANQ_PATH=
```

Run ./freshrss-opml-extractor.rb periodically.