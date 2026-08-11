<?php

namespace App\Notifications;

use App\Models\Commitment;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class CommitmentReminderNotification extends Notification
{
    use Queueable;

    public function __construct(
        public Commitment $commitment,
        public int $minutesBefore
    ) {}

    public function via(object $notifiable): array
    {
        return ['mail', 'database'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $label = $this->minutesBefore >= 60
            ? round($this->minutesBefore / 60).' hora(s)'
            : $this->minutesBefore.' minuto(s)';

        return (new MailMessage)
            ->subject('Recordatorio: '.$this->commitment->title)
            ->greeting('Hola '.$notifiable->name)
            ->line("Tu compromiso comienza en {$label}.")
            ->line('Empresa: '.$this->commitment->company->name)
            ->line('Título: '.$this->commitment->title)
            ->line('Inicio: '.$this->commitment->starts_at->format('d/m/Y H:i'))
            ->line('Fin: '.$this->commitment->ends_at->format('d/m/Y H:i'))
            ->when($this->commitment->location, fn ($mail) => $mail->line('Ubicación: '.$this->commitment->location))
            ->action('Ver agenda', url('/'));
    }

    public function toArray(object $notifiable): array
    {
        return [
            'commitment_id' => $this->commitment->id,
            'title' => $this->commitment->title,
            'company' => $this->commitment->company->name,
            'starts_at' => $this->commitment->starts_at->toIso8601String(),
            'minutes_before' => $this->minutesBefore,
            'message' => "Compromiso en {$this->minutesBefore} min: {$this->commitment->title}",
        ];
    }
}
