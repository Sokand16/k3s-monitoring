#!/bin/bash
set -e

echo "Установка k3s"
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
chmod 600 ~/.kube/config

echo "Установка Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Установка мониторинга"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Создание namespace monitoring"
kubectl create namespace monitoring

echo "Установика стека grafana + prometheus"
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=prom-operator \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo "Применение Ingress"
kubectl apply -f ingress.yaml

echo "Перезапуск k3s для применения настроек"
sudo systemctl restart k3s

echo "Готово!"
echo "Grafana: http://localhost:8080 (admin / prom-operator)"
echo "Prometheus: http://localhost:9090"
