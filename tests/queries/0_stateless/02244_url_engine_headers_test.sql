select * from url(url_with_headers, url='http://127.0.0.1:8123?query=select+12', format='RawBLOB'); -- { serverError RECEIVED_ERROR_FROM_REMOTE_IO_SERVER }
select * from url(url_with_headers, url='http://127.0.0.1:8123?query=select+12', format='RawBLOB', headers('X-Datastore-Database'='default'));
select * from url(url_with_headers, url='http://127.0.0.1:8123?query=select+12', format='RawBLOB', headers('X-Datastore-Database'='default', 'X-Datastore-Format'='JSONEachRow'));
select * from url(url_with_headers, url='http://127.0.0.1:8123?query=select+12', format='RawBLOB', headers('X-Datastore-Database'='kek')); -- { serverError RECEIVED_ERROR_FROM_REMOTE_IO_SERVER }
select * from url('http://127.0.0.1:8123?query=select+12', 'RawBLOB');
select * from url('http://127.0.0.1:8123?query=select+12', 'RawBLOB', headers('X-Datastore-Database'='default'));
select * from url('http://127.0.0.1:8123?query=select+12', 'RawBLOB', headers('X-Datastore-Database'='default', 'X-Datastore-Format'='JSONEachRow'));
select * from url('http://127.0.0.1:8123?query=select+12', 'RawBLOB', headers('X-Datastore-Format'='JSONEachRow', 'X-Datastore-Database'='kek')); -- { serverError RECEIVED_ERROR_FROM_REMOTE_IO_SERVER }
select * from url('http://127.0.0.1:8123?query=select+12', 'RawBLOB', headers('X-Datastore-Format'='JSONEachRow', 'X-Datastore-Database'=1)); -- { serverError BAD_ARGUMENTS }
drop table if exists url;
create table url (i String) engine=URL('http://127.0.0.1:8123?query=select+12', 'RawBLOB', headers('X-Datastore-Format'='JSONEachRow'));
select * from url;
