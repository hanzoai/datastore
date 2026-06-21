SELECT 'https://www.datastore.com/' AS s, REGEXP_REPLACE(s, '^https?://(?:www\.)?([^/]+)/.*$', '\1');
