# Redis RDB Used Memory Extractor
This project provides a simple Bash script and an optimized Dockerfile to extract the "used-mem" auxiliary field from a Redis RDB (Redis Database) snapshot file. It's specifically designed to interpret the memory size based on a known RDB file format structure where the used-mem value is encoded as a 32-bit little-endian integer.

## Features
- Extracts the used-mem auxiliary field from Redis RDB files.
- Interprets the memory size as a 32-bit little-endian integer.
- Converts the raw byte value to Megabytes (MB) for human-readable output.
- Packaged in an optimized Docker image for easy deployment and execution without local dependencies.

## Prerequisites
Docker installed on your system.

## Usage
### Building the Docker Image
First, clone this repository (or create the Dockerfile and parse_rdb_used_mem.sh files in a directory):

`git clone https://github.com/FalkorDB/rdb-used-memory`
cd rdb-used-memory

Then, build the Docker image from the Dockerfile:

`docker build -t rdb-used-memory .`

### Running the Docker Container
To extract the used-mem from your RDB file, you need to mount your RDB file into the Docker container. Replace /path/to/your/dump.rdb with the actual path to your Redis RDB file.

`docker run --rm -v /path/to/your/dump.rdb:/app/dump.rdb rdb-used-memory /app/dump.rdb`

Example Output:

`1411560`

If the used-mem field with the expected prefix is not found, an error message will be displayed.
