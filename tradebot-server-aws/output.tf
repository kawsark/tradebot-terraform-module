#AWS outputs
output "queue_id" {
  value = "${aws_sqs_queue.tradebot_queue.id}"
}

output "queue_arn" {
  value = "${aws_sqs_queue.tradebot_queue.arn}"
}
