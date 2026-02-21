# README.md  
# k3s Monitoring Demo.

Простой стек мониторинга **Prometheus + Grafana** на **k3s** (Ubuntu 24.04 в VirtualBox).

### Возможности.

- Мониторинг кластера Kubernetes (CPU, RAM, Disk, Pods)  
- Готовые дашборды в Grafana  
- Доступ к Prometheus и Grafana с хоста   
 
### Требования.   
Ubuntu 24.04 в VirtualBox   
Сеть: NAT   
Port Forwarding в VirtualBox: Name → Grafana, Host 8080 → Guest 80  
Port Forwarding в VirtualBox: Name → Prometheus, Host 9090 → Guest 90  

### Автоматическая установка.
```bash
git clone https://github.com/Sokand16/k3s-monitoring.git
cd k3s-monitoring-demo
./deploy.sh
```
# Ручная установка.

## Шаг 1: Установка k3s.

```bash
curl -sfL https://get.k3s.io | sh - # Если не удается скачать, смотри обходной путь установки k3s
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
chmod 600 ~/.kube/config
```
Проверка:
```bash
kubectl get nodes # Должна быть одна нода в состоянии Ready
```

### Обходной путь установки k3s.

#### Используйте прямую ссылку на бинарник (если GitHub доступен).
```
export K3S_VERSION=v1.31.4+k3s1  # Переменная окружения, которая задаёт конкретную версию K3s.

sudo curl -L --fail "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s" -o /usr/local/bin/k3s
sudo chmod +x /usr/local/bin/k3s
```

#### Скачайте скрипт через браузер (если у вас есть GUI).
Откройте на хосте: https://get.k3s.io
Сохраните как install-k3s.sh
Перенесите его в VM

#### Затем запустите установку без скачивания.
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true sudo sh -

## Проверьте, что всё работает

**1. Статус службы**  
sudo systemctl status k3s

**2. Версия и подключение к кластеру**  
sudo k3s kubectl get nodes

**3. Все системные поды (включая Traefik!)**  
sudo k3s kubectl get pods -A
k3s kubectl get pods -n monitoring

**Скопируйте kubeconfig**  
**1. Создайте каталог от своего имени**  
mkdir -p ~/.kube  

**2. Скопируйте файл через sudo, но сразу исправить владельца**  
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config  
sudo chown $USER:$USER ~/.kube/config  
chmod 600 ~/.kube/config  

**Установить переменную окружения KUBECONFIG, чтобы не использовать SUDO**   
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc   
source ~/.bashrc   

**Проверьте ноды**   
kubectl get nodes   
**Должна быть одна нода в состоянии Ready**  

Пример вывода:   
user@user:~$ kubectl get nodes   
NAME   STATUS   ROLES                  AGE    VERSION   
user   Ready    control-plane,master   171m   v1.31.4+k3s1   



## Шаг 2: Установка Helm.

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Шаг 3: Установка мониторинга.

```bash
# Добавьте репозиторий
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Создайте namespace
kubectl create namespace monitoring

# Установите стек
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=prom-operator \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```
Нужно подождать пару минут, пока все поды не запустятся.

Проверка:

```bash
kubectl get pods -n monitoring # Все поды должны быть в состоянии Running
```

## Шаг 4: Настройка Ingress для Grafana.
Создайте файл ingress.yaml:

```bash
cat > ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: ""
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-grafana
                port:
                  number: 80

…EOF
```
Примените Ingress:

```bash
kubectl apply -f ingress.yaml
```
Проверка:

```bash
kubectl get ingress -n monitoring # Должен быть grafana-ingress с ADDRESS и PORTS=80
```


## Шаг 5: Настройка проброса портов в VirtualBox для Grafana и Prometheus.
 
Зайдите в VirtualBox: Настройки → Сеть → NAT → Дополнительно → Проброс портов   
Добавьте правила:   
Имя grafana   
Протокол TCP     
IP хоста пусто   
Порт хоста 8080   
IP гостя пусто   
Порт гостя 80

Имя prometheus    
Протокол TCP     
IP хоста пусто   
Порт хоста 9090   
IP гостя пусто   
Порт гостя 9090  

<img width="597" height="204" alt="image" src="https://github.com/user-attachments/assets/cd2f1b0d-af46-438f-817a-359edf00aa15" />



## ✅ Шаг 6: Проверка доступа к Grafana с хоста.
Откройте в браузере хоста: http://localhost:8080   

Вы увидите страницу входа Grafana.   

Логин: admin   
Пароль: prom-operator   

## Шаг 7: Запустите port-forward внутри ВМ.
В терминале Ubuntu-ВМ выполните:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

**Эта команда перенаправляет локальный порт 9090 на сервис Prometheus.**

## Шаг 8: Проверка доступа Prometheus с хоста.
Откройте в браузере хоста: http://localhost:9090  

Вы увидите UI Prometheus.


## Метрики.  
Prometheus автоматически собирает метрики:  
С нод Kubernetes (через Node Exporter)  
С подов, сервисов, control plane  

Grafana автоматически подключается к Prometheus как источнику данных  
Готовые дашборды уже загружены   

Откройте Grafana: http://localhost:8080  
Войдите: admin / prom-operator  
Перейдите: Dashboards → Manage  
Выберите нужный Dashboards     
Например:  

Kubernetes / Compute Resources / Cluster — нагрузка на весь кластер  
Kubernetes / Compute Resources / Namespace (Pods) — по неймспейсам  
Node Exporter / Nodes — CPU, RAM, Disk по каждой ноде  

<img width="1781" height="825" alt="image" src="https://github.com/user-attachments/assets/6f15d7a3-ae07-4a54-bfce-5ca3704644d2" />


## Посмотреть, что метрики собираются в Prometheus:  
Откройте http://localhost:9090  
В строке запроса введите:  
```
up  # покажет все активные таргеты.
```
Или:
```
node_cpu_seconds_total # Метрики CPU от Node Exporter.
```

****<img width="1286" height="792" alt="image" src="https://github.com/user-attachments/assets/1cd72d0e-faff-4480-bd1d-ed5178a2437f" />


## 📂 Структура проекта
```
k3s-monitoring-demo/
├── README.md
├── LICENSE
├── .gitignore
├── deploy.sh                 ← скрипт автоматической установки k3s
├── ingress.yaml              ← Ingress для Grafana
```
