# Demo App

A simple Flask web application with basic health check and version endpoints.

## Supported Endpoints

- `GET /healthz` - Returns a health check status
  - Response: `{"status": "ok"}`

- `GET /version` - Returns the application version
  - Response: The value of the `APP_VERSION` environment variable, or `"unknown"` if not set

## Running the App Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the server
flask --app server run
```

## Running the App in Kubernetes



## Adding More Routes

To add additional endpoints to this Flask app, check out the official Flask documentation on routing:

[Flask Routing Documentation](https://flask.palletsprojects.com/en/stable/quickstart/#routing)

Basic example:
```python
@app.route("/your-endpoint")
def your_function():
    return {"message": "Hello!"}
```
