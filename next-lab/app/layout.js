export const metadata = {
  title: 'Next lab · php2shell-demo',
  description: 'App Next mínima para la escena post-explotación (laboratorio defensivo).',
};

export default function RootLayout({ children }) {
  return (
    <html lang="es">
      <body style={{ fontFamily: 'system-ui', maxWidth: '40rem', margin: '4rem auto' }}>
        {children}
      </body>
    </html>
  );
}
