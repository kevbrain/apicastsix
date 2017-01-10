# s2i way of packaging customizations

Source-to-image can be used to create Docker image with baked in customizations.

## Build

```sh
s2i build . quay.io/3scale/apicast:master my-image-name
```

## Test

```sh
docker run --ENV THREESCALE_CONFIG_FILE=config.json my-image-name
```

And container will start without any error messages.
