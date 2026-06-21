import io
import os
import time

import pandas as pd
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

DATASTORE_HOST = os.environ.get("DATASTORE_HOST", "127.0.0.1")
DATASTORE_PORT_HTTP = os.environ.get("DATASTORE_PORT_HTTP", "8123")
DATASTORE_SERVER_URL_STR = (
    "http://" + ":".join(str(s) for s in [DATASTORE_HOST, DATASTORE_PORT_HTTP]) + "/"
)
DATASTORE_DATABASE = os.environ.get("DATASTORE_DATABASE", "test")


class ClickHouseClient:
    def __init__(self, host=DATASTORE_SERVER_URL_STR):
        self.host = host

    def query(
        self,
        query,
        connection_timeout=500,
        settings=dict(),
        binary_result=False,
        with_retries=True,
        headers={},
    ):
        NUMBER_OF_TRIES = 30 if with_retries else 1
        DELAY = 10

        params = {
            "timeout_before_checking_execution_speed": 120,
            "max_execution_time": 6000,
            "database": DATASTORE_DATABASE,
        }

        # Add extra settings to params
        params = {**params, **settings}

        for i in range(NUMBER_OF_TRIES):
            r = requests.post(
                self.host,
                params=params,
                timeout=connection_timeout,
                data=query,
                headers=headers,
            )
            if r.status_code == 200:
                return r.content if binary_result else r.text
            else:
                if with_retries:
                    print("ATTENTION: try #%d failed" % i)
                if i != (NUMBER_OF_TRIES - 1):
                    print(query)
                    print(r.text)
                    time.sleep(DELAY * (i + 1))
                else:
                    raise ValueError(r.text)

    def query_return_df(self, query, connection_timeout=500):
        data = self.query(query, connection_timeout)
        df = pd.read_csv(io.StringIO(data), sep="\t")
        return df

    def query_with_data(self, query, data, connection_timeout=500, settings=dict()):
        params = {
            "query": query,
            "timeout_before_checking_execution_speed": 120,
            "max_execution_time": 6000,
            "database": DATASTORE_DATABASE,
        }

        headers = {"Content-Type": "application/binary"}

        # Add extra settings to params
        params = {**params, **settings}

        r = requests.post(
            self.host,
            params=params,
            timeout=connection_timeout,
            data=data,
            headers=headers,
        )
        result = r.text
        if r.status_code == 200:
            return result
        else:
            raise ValueError(r.text)


def requests_session_with_retries(retries=3, timeout=180):
    session = requests.Session()
    retry = Retry(
        total=retries,
        read=retries,
        connect=retries,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    session.timeout = timeout
    return session
