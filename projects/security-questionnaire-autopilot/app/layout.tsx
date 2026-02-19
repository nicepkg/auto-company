import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "Security Questionnaire Autopilot",
  description: "Hosted ingest -> draft -> approve -> export workflow"
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "ui-sans-serif, system-ui, -apple-system" }}>
        {children}
      </body>
    </html>
  );
}
