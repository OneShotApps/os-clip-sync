import nodemailer from 'nodemailer';

/**
 * Creates the SMTP-backed passwordless email sender.
 *
 * @param {object} smtp - Validated SMTP configuration.
 * @returns {{sendSignInCode: function}} Email service.
 */
export function createEmailService(smtp) {
  const transporter = nodemailer.createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    auth: smtp.user ? { user: smtp.user, pass: smtp.password } : undefined,
  });

  return {
    /** Sends a six-digit Clip Sync sign-in code. */
    async sendSignInCode({ email, code, expiresInMinutes }) {
      await transporter.sendMail({
        from: smtp.from,
        to: email,
        subject: 'Your Clip Sync sign-in code',
        text: `Your Clip Sync sign-in code is ${code}. It expires in ${expiresInMinutes} minutes.`,
        html: `<p>Your Clip Sync sign-in code is <strong>${code}</strong>.</p><p>It expires in ${expiresInMinutes} minutes.</p>`,
      });
    },
  };
}
