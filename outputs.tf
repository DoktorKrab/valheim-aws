output "server_address" {
  description = "Adres do wpisania w Valheim (Dołącz do gry -> Dodaj serwer)."
  value       = "${aws_eip.valheim.public_ip}:2456"
}

output "instance_id" {
  value = aws_instance.valheim.id
}

output "ssm_connect" {
  description = "Shell na serwerze (wymaga session-manager-plugin)."
  value       = "aws ssm start-session --region ${var.region} --target ${aws_instance.valheim.id}"
}

output "stop_command" {
  description = "Zatrzymaj serwer, gdy nikt nie gra (płacisz wtedy tylko za dyski i IP)."
  value       = "aws ec2 stop-instances --region ${var.region} --instance-ids ${aws_instance.valheim.id}"
}

output "start_command" {
  value = "aws ec2 start-instances --region ${var.region} --instance-ids ${aws_instance.valheim.id}"
}

