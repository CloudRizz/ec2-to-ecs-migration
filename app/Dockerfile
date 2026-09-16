# =============================================================================
# Build Stage
# =============================================================================
# Use a lightweight Python image to build the application's dependencies.
# Building dependencies separately keeps build tooling out of the final image.

FROM python:3.11-slim AS builder

# Prevent Python from writing .pyc files during the image build. 
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure Python logs are written directly to stdout/stderr instead of being
# buffered. This is important because ECS will send these streams to
# CloudWatch Logs.
ENV PYTHONUNBUFFERED=1

# Set the working directory for the build stage.
WORKDIR /app

# Copy the dependency file separately so Docker can reuse this layer when
# application code changes but Python dependencies do not. 
COPY requirements.txt .

# Build Python dependency wheels.
# Wheels can then be installed into the runtime image without carrying
# unnecessary build artifacts into the final container.

RUN pip wheel \
--no-cache-dir \
--wheel-dir /wheels \
-r requirements.txt

# =============================================================================
# Runtime Stage
# =============================================================================
# Start again from a clean Python image so the final container contains only
# what is required to run the Flask application.

FROM python:3.11-slim AS runtime

# Configure Python for containerised execution.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Set the working directory used by Gunicorn.
WORKDIR /app

# -----------------------------------------------------------------------------
# Non-root User
# -----------------------------------------------------------------------------
# Containers should not run the application as root.
# Create a dedicated system user with no interactive login shell.

RUN groupadd --system appgroup \
    && useradd \
        --system \
        --gid appgroup \
        --no-create-home \
        --shell /usr/sbin/nologin \
        appuser

# -----------------------------------------------------------------------------
# Python Dependencies
# -----------------------------------------------------------------------------
# Copy the pre-built dependency wheels from the builder stage and install them.

COPY --from=builder /wheels /wheels
COPY requirements.txt .

RUN pip install \
    --no-cache-dir \
    --no-index \
    --find-links=/wheels \
    -r requirements.txt \
    && rm -rf /wheels

# -----------------------------------------------------------------------------
# Application
# -----------------------------------------------------------------------------
# Copy only the application source required by the runtime container.

COPY app.py .
COPY wsgi.py .

# Transfer ownership of the application directory to the non-root user.
RUN chown -R appuser:appgroup /app

# Drop root privileges before starting the application.
USER appuser


# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
# Gunicorn listens on port 5000. The ECS target group will later forward
# traffic from the Application Load Balancer to this container port.

EXPOSE 5000


# -----------------------------------------------------------------------------
# Container Health Check
# -----------------------------------------------------------------------------
# Reuse the application's existing /health endpoint.
# Python's standard library is used instead of installing curl solely for the
# health check, keeping the runtime image smaller.

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1


# -----------------------------------------------------------------------------
# Application Startup
# -----------------------------------------------------------------------------
# Run the Flask application through Gunicorn rather than Flask's development
# server. Logs are written to stdout/stderr for collection by ECS/CloudWatch.

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "wsgi:app"]