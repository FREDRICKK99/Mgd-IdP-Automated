# Mgd-IdP-Automated
# **FreeRADIUS Automated Deployment with Ansible and Docker**

## **📌 Overview**
This project automates the **configuration and deployment** of **FreeRADIUS** servers using **Ansible** and **Docker**.  
It processes **institution data from CSV files**, dynamically updates FreeRADIUS configurations, and creates isolated **Docker containers** for each batch.

✅ **Splits the CSV into batches of 50 institutions**  
✅ **Processes one batch at a time** (copies files, runs Ansible, creates a container)  
✅ **Dynamically generates FreeRADIUS configs (`eduroam`, `eduroam-inner-tunnel`)**  
✅ **Replaces `if` and `elsif` conditions dynamically**  
✅ **Ensures proper LDAP configurations in `Auth-Type PAP`, `eap`, and authorization blocks**  

---

## **📂 Project Structure**
```bash
/home/Test/
│── deploy.sh                  # Main deployment script  
│── mgd-idp-automation.yml      # Ansible playbook for FreeRADIUS configuration  
│── schools.csv                 # Institutions list (split into batches)  
│── split_csv/                  # Folder for split CSV files  
│── generated/                   # Folder for generated FreeRADIUS configs  
│   ├── schools_aa/              # Batch-specific files  
│   │   ├── proxy.conf  
│   │   ├── ldap  
│   │   ├── eduroam  
│   │   ├── eduroam-inner-tunnel  
│── RENU-Mgd-IdP-dockerized/     # Docker build files  
│   ├── Dockerfile  
│   ├── ca.cnf  
│   ├── client.cnf  
│   ├── server.cnf  
│   ├── eap  
│   ├── clients.conf  
│── inventory.ini                # Ansible inventory file  

