export interface DiagnosticMessage {
  severity: 'info' | 'warning' | 'error';
  category: 'uniform' | 'channel' | 'pass' | 'general';
  message: string;
}
