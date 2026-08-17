<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('recurring_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('client_name')->nullable();
            $table->enum('category', ['payment', 'invoice', 'reminder', 'general'])->default('general');
            $table->decimal('amount', 12, 2)->nullable();
            $table->enum('recurrence', ['daily', 'weekly', 'monthly', 'yearly'])->default('monthly');
            $table->unsignedTinyInteger('day_of_month')->nullable(); // 1-31
            $table->unsignedTinyInteger('weekday')->nullable(); // 1=lunes … 7=domingo
            $table->unsignedTinyInteger('month')->nullable(); // 1-12 para yearly
            $table->unsignedTinyInteger('time_hour')->default(9);
            $table->unsignedTinyInteger('time_minute')->default(0);
            $table->unsignedSmallInteger('duration_minutes')->default(30);
            $table->json('reminder_minutes')->nullable();
            $table->date('starts_on');
            $table->date('ends_on')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['user_id', 'is_active']);
        });

        Schema::table('commitments', function (Blueprint $table) {
            $table->foreignId('recurring_event_id')->nullable()->after('company_id')->constrained()->nullOnDelete();
            $table->string('occurrence_key', 10)->nullable()->after('recurring_event_id'); // YYYY-MM-DD

            $table->unique(['recurring_event_id', 'occurrence_key']);
        });
    }

    public function down(): void
    {
        Schema::table('commitments', function (Blueprint $table) {
            $table->dropUnique(['recurring_event_id', 'occurrence_key']);
            $table->dropConstrainedForeignId('recurring_event_id');
        });

        Schema::dropIfExists('recurring_events');
    }
};
