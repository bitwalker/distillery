# Deploying to Google Cloud Platform

Google Cloud Platform provides several ways to deploy an application. For this guide,
we will walk through how to deploy an application using Google Compute Engine.

For this walkthough, we will accomplish the following:

* Install the Cloud SQL Proxy
* Deploy the release
* Connect to Cloud SQL PostgreSQL instance
* Manage Cloud SQL Proxy and app with systemd
* Expose the app on port 80

## Prerequisites

You will need to have the performed the following to complete this guide:

  * A running VM in Google Compute Engine with access to the Cloud SQL scope enabled
    * [Creating a VM on GCE](https://cloud.google.com/compute/docs/instances/create-start-instance)
  * A Cloud SQL instance
    * [Creating a Cloud SQL instance](https://cloud.google.com/sql/docs/postgres/create-instance)
  * Enabled Cloud SQL Admin API
    * [Enabling and Disabling APIs](https://cloud.google.com/apis/docs/enable-disable-apis)
  * Cloud SQL instance and GCE instance under the same project
  * Google Cloud SDK installed and configured
    * [Configuring the CLI](https://cloud.google.com/sdk/docs/quickstarts)
  * A release targeted for the VM's operating system
    * [Distillery Walkthrough](../introduction/walkthrough.md)

## Connecting the VM to Cloud SQL

We will connect the VM to Cloud SQL by using the Cloud SQL Proxy. This will allow us
to connect to the Cloud SQL instance without having to whitelist the VM and automatically
have a secure connection to our database.

### Installing Cloud SQL Proxy

Connect to your instance over SSH.

```
$ gcloud compute ssh <instance-name>
```

Install the Cloud SQL Proxy.

```
$ sudo wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /opt/cloud_sql_proxy
$ sudo chmod +x /opt/cloud_sql_proxy
```

### Add Cloud SQL Proxy as a Service

Make Cloud SQL Proxy a service that can be managed by systemd. Create the file
`/etc/systemd/system/cloud-sql-proxy.service` with the following contents:

```
[Install]
WantedBy=multi-user.target

[Unit]
Description=Cloud SQL Proxy
Requires=networking.service
After=networking.service

[Service]
Type=simple
WorkingDirectory=/opt
ExecStart=/opt/cloud_sql_proxy -dir=/cloudsql
Restart=always
StandardOutput=journal
User=root
```

Now enable Cloud SQL Proxy to start on boot as well as start for the current session.

```
$ sudo systemctl enable cloud-sql-proxy
$ sudo systemctl start cloud-sql-proxy
```

### Configuring Ecto

Update your application's `repo.ex` file to be able to handle accepting a socket value
as an environment variable.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Read database configuration values from the environment.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :socket, System.get_env("DATABASE_SOCKET"))}
  end
end
```

## Deploying the Application

Let's configure the application to be located in the `/opt` directory on our server. Create a new directory
for the app.

```
$ sudo mkdir /opt/my_app
```

Upload your application's release from your local machine to the server.

```
$ gcloud compute scp releases/my_app/releases/<version>/my_app.tar.gz <instance-name>:~/
```

Unpack the application from the VM's SSH session.

```
$ sudo cp ~/my_app.tar.gz /opt/my_app
$ sudo cd /opt/my_app
$ sudo tar -zxvf my_app.tar.gz
```

Now we can start the application and connect to the database.

```
$ PORT=80 DATABASE_SOCKET="/cloudsql/<gcp-project>:<region>:<db-instance-name>/.s.PGSQL.5432" /opt/my_app/bin/my_app foreground
```

You should be able to view the Phoenix application by going to the VM's external IP address.

## Adding The Application as a Service

Let's add the application a new service that can be managed by systemd. We can also configure our service to wait for our Cloud
SQL Proxy service to be started before allowing the app to start.

Create a new service for the application at `/etc/systemd/system/my_app.service` with these values as a starter configuration:

```
[Unit]
Description=My App
Requires=cloud-sql-proxy.service
After=cloud-sql-proxy.service

[Service]
Type=simple
User=root
Group=root
SyslogIdentifier=my_app
WorkingDirectory=/opt/my_app
ExecStart=/opt/my_app/bin/my_app foreground
Restart=on-failure
RestartSec=5
RemainAfterExit=no
Environment=PORT=80
Environment=DATABASE_SOCKET=/cloudsql/<gcp-project>:<region>:<db-instance-name>/.s.PGSQL.5432

[Install]
WantedBy=multi-user.target
```

Reload the systemd daemon and allow our app to run.

```
$ systemctl enable my_app
$ systemctl start my_app
```

Now your app should be automically started and managed by systemd.

## Wrap Up

Now that you can deploy to GCP, There's still much more you can do to enhance
your application with server configuration but now you have a good start at a
running application.
