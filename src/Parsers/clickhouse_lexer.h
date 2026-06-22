#pragma once

#ifdef __cplusplus
extern "C" {
#endif

extern unsigned long datastore_lexer_size;
void datastore_lexer_create(void * ptr, const char * begin, const char * end, unsigned long max_query_size);
unsigned char datastore_lexer_next_token(void * ptr, const char ** out_token_begin, const char ** out_token_end);
int datastore_lexer_token_is_significant(unsigned char token);
int datastore_lexer_token_is_error(unsigned char token);
int datastore_lexer_token_is_end(unsigned char token);

#ifdef __cplusplus
}
#endif
