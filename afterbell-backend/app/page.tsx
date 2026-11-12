export default function Home() {
  return (
    <main style={{ maxWidth: 560 }}>
      <h1 style={{ margin: '0 0 8px' }}>Afterbell app backend</h1>
      <p>This service connects the Afterbell mobile app to the Afterbell website.</p>
      <p>
        Status check: <a href="/api/health">/api/health</a>
      </p>
    </main>
  );
}
