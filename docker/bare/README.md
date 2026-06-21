## The bare minimum Hanzo Datastore Docker image.

It is intended as a showcase to check the amount of implicit dependencies of Hanzo Datastore from the OS in addition to the OS kernel.

Example usage:

```
./prepare
docker build --tag hanzo-datastore-bare .
```

Run hanzo-datastore-local:
```
docker run -it --rm --network host hanzo-datastore-bare /hanzo-datastore local --query "SELECT 1"
```

Run hanzo-datastore-client in interactive mode:
```
docker run -it --rm --network host hanzo-datastore-bare /hanzo-datastore client
```

Run hanzo-datastore-server:
```
docker run -it --rm --network host hanzo-datastore-bare /hanzo-datastore server
```

It can be also run in chroot instead of Docker (first edit the `prepare` script to enable `proc`):

```
sudo chroot . /hanzo-datastore server
```

## What does it miss?

- creation of `hanzo-datastore` user to run the server;
- VOLUME for server;
- CA Certificates;
- most of the details, see other docker images for comparison;
