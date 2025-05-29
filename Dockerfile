# Use a minimal Alpine Linux base image
FROM alpine:3.21

# Install xxd, which is part of the 'vim' package in Alpine
# We also install bash as our script is a bash script
RUN apk update && \
  apk add --no-cache bash vim && \
  rm -rf /var/cache/apk/*

# Copy the script into the container
# Assuming your script is named 'rdb-used-memory.sh' and is in the same directory as the Dockerfile
COPY rdb-used-memory.sh /usr/local/bin/rdb-used-memory

# Make the script executable
RUN chmod +x /usr/local/bin/rdb-used-memory

# Define the entrypoint for the container.
# This ensures that when the container runs, it executes our script.
# We use exec form to ensure proper signal handling.
ENTRYPOINT ["/usr/local/bin/rdb-used-memory"]