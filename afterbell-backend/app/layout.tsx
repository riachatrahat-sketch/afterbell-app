export const metadata = { title: 'Afterbell app backend' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, sans-serif', margin: 0, padding: 32, background: '#f6f7fc', color: '#0e1633' }}>{children}</body>
    </html>
  );
}
