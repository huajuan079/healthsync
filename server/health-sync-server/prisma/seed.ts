import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const SALT_ROUNDS = 12;

  // Create default users
  const users = [
    { username: 'zhugong', password: 'zhugong123' },
    { username: 'dage', password: 'dage123' },
  ];

  for (const user of users) {
    const hashedPassword = await bcrypt.hash(user.password, SALT_ROUNDS);

    await prisma.user.upsert({
      where: { username: user.username },
      update: {},
      create: {
        username: user.username,
        password: hashedPassword,
        role: 'user',
        isActive: true,
      },
    });

    console.log(`✓ User created: ${user.username} (password: ${user.password})`);
  }

  console.log('\n✅ Database initialized successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
