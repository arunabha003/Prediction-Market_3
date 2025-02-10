import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import Link from 'next/link';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Prediction Markets',
  description: 'Create and trade prediction markets across multiple chains',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <nav className="bg-gray-800 p-4">
          <div className="max-w-7xl mx-auto flex justify-between">
            <Link href="/" className="text-white px-3 py-2 rounded-md text-sm font-medium">
              Home
            </Link>
            <Link href="/markets" className="text-white px-3 py-2 rounded-md text-sm font-medium">
              Markets
            </Link>
          </div>
        </nav>
        <main>{children}</main>
      </body>
    </html>
  );
}