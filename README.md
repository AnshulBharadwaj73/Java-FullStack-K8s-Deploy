This is a FullStack Java K8s app deploy on minikube
Note: the App is taken from hungarycoders and deployment is done my me.

# Healthcare Microservices Project by HungryCoders

This project is a **Healthcare Microservices System** designed for self-learning and interview preparation. It includes services for authentication, appointments, doctor and patient management, notifications, and more. The system is implemented using **Spring Boot**, **Kafka**, **MongoDB**, **ReactJS**, and **Docker**.

---

## Prerequisites

1. **Install the following tools**:
    - [Java 17](https://openjdk.org/)
    - [Maven](https://maven.apache.org/install.html)
    - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
    - [Docker Compose](https://docs.docker.com/compose/install/) (if not bundled with Docker Desktop)
    - [MongoDB Compass](https://www.mongodb.com/products/compass) (optional, for data inspection)

2. **Configure email functionality**:
    - Update `MAIL_SERVER_USERNAME` and `MAIL_SERVER_PASSWORD` in the `docker-compose.yml` file.

---

## Architecture

The project consists of the following microservices:

1. **Auth Service**: Manages authentication and authorization.
2. **Doctor Service**: Handles doctor-related operations.
3. **Patient Service**: Handles patient-related operations.
4. **Appointment Service**: Manages appointments and sends events to Kafka.
5. **Notification Service**: Listens to Kafka events and sends notifications via email.
6. **Admin Service**: Provides centralized monitoring using Spring Boot Admin.
7. **Gateway Service**: Routes requests to other services and includes circuit breaker patterns.
8. **UI Service**: A ReactJS-based frontend for user interaction.
9. **MongoDB**: Stores data for all services.
10. **Kafka**: Facilitates asynchronous communication between services.

---

## How to Run

### Step 1: Start the System
Run the following command to build and start all services:
```bash
docker-compose up --build
```

### Step 2: Access the System
- **Gateway API**: [http://localhost:8080](http://localhost:8080)
- **Admin Panel**: [http://localhost:9093](http://localhost:9093)
- **React UI**: [http://localhost:9090](http://localhost:9090)

---

## Environment Variables

Ensure the following environment variables are correctly set in the `docker-compose.yml` file:

- **MongoDB**:
    - `MONGO_INITDB_ROOT_USERNAME`
    - `MONGO_INITDB_ROOT_PASSWORD`
- **Kafka**:
    - `KAFKA_BOOTSTRAP_SERVER`
    - `KAFKA_TOPIC`
- **Mail Server**:
    - `MAIL_SERVER_HOST`
    - `MAIL_SERVER_PORT`
    - `MAIL_SERVER_USERNAME`
    - `MAIL_SERVER_PASSWORD`

---

## Key Features

1. **Authentication**:
    - Register and log in using the Auth Service.
    - Secure communication using JWT.

2. **Service Monitoring**:
    - Admin Service provides centralized monitoring for all microservices.

3. **Notification**:
    - Notification Service sends emails based on appointment status.

4. **UI Integration**:
    - ReactJS frontend communicates with backend services via Gateway Service.

5. **Asynchronous Communication**:
    - Kafka ensures event-driven communication between services.

---

## Troubleshooting

1. **MongoDB not starting**:
    - Ensure the `mongo-data` volume is correctly mounted.
    - Check if the port `27017` is already in use.

2. **Kafka issues**:
    - Verify the `KAFKA_BOOTSTRAP_SERVER` in `docker-compose.yml`.

3. **Email sending errors**:
    - Confirm email credentials (`MAIL_SERVER_USERNAME` and `MAIL_SERVER_PASSWORD`).

4. **UI not loading**:
    - Ensure the UI Service is running at [http://localhost:9090](http://localhost:9090).

---

## Stopping the System
To stop all services, run:
```bash
docker-compose down
```

---

## License

This project is for educational purposes and self-learning only. It is available only for paid users of HungryCoders course users.


# Minikube(Mac only)
    brew update
    brew install minikube
    brew install kubectl

# Start Minikube
    start minikube  

# Add ingress and metrics-server 
    minikube addons enable ingress metrics-server

# Check Status
    minikube status :- the apiserver, host, kubelet must be in running state

# Deploy on minikube    
    kubectl apply -f ./k8s

# Check pods are running    
    kubectl get pods -n healthcare

# Start tunnel(ingress to communicate with the internet)
    minikube tunnel

# Add healtcare.local to /etc/hosts to avoid coors error
    sudo vim /etc/hosts
    then Add
    127.0.0.1 healthcare.local


# Todo
    Helm Chart 
    Deploy on cloud
    Add monitoring
    CICD pipeline
