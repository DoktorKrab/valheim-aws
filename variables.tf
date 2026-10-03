variable "region" {
  description = "Region AWS (eu-central-1 = Frankfurt, najniższy ping z Polski)."
  type        = string
  default     = "eu-central-1"
}

variable "name" {
  description = "Prefiks nazw zasobów AWS."
  type        = string
  default     = "valheim"
}

variable "instance_type" {
  description = "Typ instancji EC2. Valheim potrzebuje ~4-8 GB RAM. m7i-flex.large (2 vCPU / 8 GB) kwalifikuje się do AWS Free Tier."
  type        = string
  default     = "m7i-flex.large"
}

variable "data_volume_size" {
  description = "Rozmiar (GB) dysku EBS na świat, backupy i pliki serwera."
  type        = number
  default     = 20
}

variable "server_name" {
  description = "Nazwa serwera widoczna w przeglądarce serwerów."
  type        = string
  default     = "Valheim AWS"
}

variable "world_name" {
  description = "Nazwa świata (pliku zapisu)."
  type        = string
  default     = "Dedicated"
}

variable "server_password" {
  description = "Hasło do serwera (min. 5 znaków, nie może zawierać nazwy serwera)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.server_password) >= 5
    error_message = "Hasło musi mieć co najmniej 5 znaków (wymóg Valheim)."
  }
}

variable "server_public" {
  description = "Czy serwer ma być widoczny na publicznej liście serwerów."
  type        = bool
  default     = false
}

variable "timezone" {
  description = "Strefa czasowa kontenera (wpływa na godziny backupów/aktualizacji)."
  type        = string
  default     = "Europe/Warsaw"
}

variable "allowed_cidrs" {
  description = "Adresy IP, które mogą łączyć się z serwerem gry."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_env" {
  description = "Dodatkowe zmienne środowiskowe dla obrazu lloesche/valheim-server (np. BEPINEX = \"true\")."
  type        = map(string)
  default     = {}
}

variable "snapshot_retention_days" {
  description = "Ile dziennych snapshotów EBS przechowywać (0 = wyłącz snapshoty)."
  type        = number
  default     = 7
}

