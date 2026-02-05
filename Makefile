# ============================================
# Makefile - Image to Cluster Automation
# Author: Steve
# ============================================

.PHONY: all install install-k3d install-packer install-ansible cluster build import deploy clean help stop-mario port-forward

# Variables
IMAGE_NAME := steve-nginx
IMAGE_TAG := latest
CLUSTER_NAME := lab

# Couleurs pour les messages
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# ============================================
# CIBLE PRINCIPALE - TOUT EN UN
# ============================================
all: install cluster build import deploy
	@echo "$(GREEN)============================================$(NC)"
	@echo "$(GREEN) DEPLOYMENT COMPLETE!$(NC)"
	@echo "$(GREEN) Open PORTS tab and access port 8080$(NC)"
	@echo "$(GREEN)============================================$(NC)"

# ============================================
# INSTALLATION DES OUTILS
# ============================================
install: install-k3d install-packer install-ansible
	@echo "$(GREEN)[OK] All tools installed$(NC)"

install-k3d:
	@echo "$(YELLOW)[INFO] Installing K3d...$(NC)"
	@which k3d > /dev/null 2>&1 || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
	@echo "$(GREEN)[OK] K3d installed$(NC)"

install-packer:
	@echo "$(YELLOW)[INFO] Installing Packer...$(NC)"
	@which packer > /dev/null 2>&1 || (cd /tmp && \
		curl -fsSL https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip -o packer.zip && \
		unzip -o packer.zip && \
		sudo mv packer /usr/local/bin/ && \
		rm packer.zip)
	@echo "$(GREEN)[OK] Packer installed$(NC)"

install-ansible:
	@echo "$(YELLOW)[INFO] Installing Ansible...$(NC)"
	@which ansible > /dev/null 2>&1 || pip install --user ansible
	@echo "$(GREEN)[OK] Ansible installed$(NC)"

# ============================================
# CREATION DU CLUSTER K3D
# ============================================
cluster: stop-mario
	@echo "$(YELLOW)[INFO] Creating K3d cluster...$(NC)"
	@k3d cluster list | grep -q $(CLUSTER_NAME) && echo "$(YELLOW)[INFO] Cluster already exists$(NC)" || \
		k3d cluster create $(CLUSTER_NAME) --servers 1 --agents 2
	@echo "$(GREEN)[OK] Cluster ready$(NC)"
	@kubectl get nodes

stop-mario:
	@echo "$(YELLOW)[INFO] Stopping Mario app if running...$(NC)"
	-@pkill -f "kubectl port-forward svc/mario" 2>/dev/null || true
	-@kubectl delete deployment mario --ignore-not-found=true --timeout=10s 2>/dev/null || true
	-@kubectl delete svc mario --ignore-not-found=true --timeout=10s 2>/dev/null || true
	@echo "$(GREEN)[OK] Mario stopped$(NC)"

# ============================================
# BUILD DE L'IMAGE AVEC PACKER
# ============================================
build:
	@echo "$(YELLOW)[INFO] Building Docker image with Packer...$(NC)"
	@cd packer && packer init nginx.pkr.hcl
	@cd packer && packer build nginx.pkr.hcl
	@echo "$(GREEN)[OK] Image built: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	@docker images | grep $(IMAGE_NAME)

# ============================================
# IMPORT DE L'IMAGE DANS K3D
# ============================================
import:
	@echo "$(YELLOW)[INFO] Importing image into K3d cluster...$(NC)"
	@k3d image import $(IMAGE_NAME):$(IMAGE_TAG) -c $(CLUSTER_NAME)
	@echo "$(GREEN)[OK] Image imported into K3d$(NC)"

# ============================================
# DEPLOIEMENT AVEC ANSIBLE
# ============================================
deploy:
	@echo "$(YELLOW)[INFO] Deploying with Ansible...$(NC)"
	@cd ansible && ansible-playbook deploy.yml
	@echo "$(GREEN)[OK] Application deployed$(NC)"
	@$(MAKE) port-forward

port-forward:
	@echo "$(YELLOW)[INFO] Setting up port-forward...$(NC)"
	-@pkill -f "kubectl port-forward svc/steve-nginx" 2>/dev/null || true
	@kubectl port-forward svc/steve-nginx 8080:80 >/tmp/steve-nginx.log 2>&1 &
	@sleep 2
	@echo "$(GREEN)[OK] Port-forward active on 8080$(NC)"
	@echo "$(GREEN)    Open PORTS tab and access port 8080$(NC)"

# ============================================
# NETTOYAGE
# ============================================
clean:
	@echo "$(YELLOW)[INFO] Cleaning up...$(NC)"
	@k3d cluster delete $(CLUSTER_NAME) || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	@echo "$(GREEN)[OK] Cleanup complete$(NC)"

# ============================================
# STATUS
# ============================================
status:
	@echo "$(YELLOW)[INFO] Cluster status:$(NC)"
	@kubectl get nodes
	@echo ""
	@echo "$(YELLOW)[INFO] Pods status:$(NC)"
	@kubectl get pods
	@echo ""
	@echo "$(YELLOW)[INFO] Services:$(NC)"
	@kubectl get svc

# ============================================
# AIDE
# ============================================
help:
	@echo "============================================"
	@echo " Image to Cluster - Makefile Help"
	@echo "============================================"
	@echo ""
	@echo " make all          - Full automation (install + build + deploy)"
	@echo " make install      - Install K3d, Packer, Ansible"
	@echo " make cluster      - Create K3d cluster"
	@echo " make build        - Build Docker image with Packer"
	@echo " make import       - Import image into K3d"
	@echo " make deploy       - Deploy app with Ansible"
	@echo " make port-forward - Setup port-forward on 8080"
	@echo " make status       - Show cluster and app status"
	@echo " make clean        - Delete cluster and image"
	@echo " make help         - Show this help"
	@echo ""
