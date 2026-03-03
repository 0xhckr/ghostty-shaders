import type { DiagnosticMessage } from './types';

type DiagnosticCategory = DiagnosticMessage['category'];
type DiagnosticSeverity = DiagnosticMessage['severity'];

export class Diagnostics {
  private messages: DiagnosticMessage[] = [];

  info(category: DiagnosticCategory, message: string): void {
    this.messages.push({ severity: 'info', category, message });
  }

  warn(category: DiagnosticCategory, message: string): void {
    this.messages.push({ severity: 'warning', category, message });
  }

  error(category: DiagnosticCategory, message: string): void {
    this.messages.push({ severity: 'error', category, message });
  }

  getMessages(): DiagnosticMessage[] {
    return [...this.messages];
  }

  hasErrors(): boolean {
    return this.messages.some((m) => m.severity === 'error');
  }

  format(): string {
    if (this.messages.length === 0) {
      return 'No diagnostics.';
    }

    const grouped: Record<DiagnosticSeverity, DiagnosticMessage[]> = {
      error: [],
      warning: [],
      info: [],
    };

    for (const msg of this.messages) {
      grouped[msg.severity].push(msg);
    }

    const sections: string[] = [];

    for (const severity of ['error', 'warning', 'info'] as const) {
      const msgs = grouped[severity];
      if (msgs.length === 0) continue;

      const label = severity === 'error' ? 'Errors' : severity === 'warning' ? 'Warnings' : 'Info';
      const lines = msgs.map((m) => `  [${m.category}] ${m.message}`);
      sections.push(`${label}:\n${lines.join('\n')}`);
    }

    return sections.join('\n\n');
  }

  clear(): void {
    this.messages = [];
  }
}
