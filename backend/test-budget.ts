import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function test() {
  const user = await prisma.user.findFirst();
  if (!user) return console.log('no user');

  const name = 'หดกฟหกฟหกฟ';
  const period = 'monthly';
  
  const existing = await prisma.budget.findFirst({
    where: {
      userId: user.id,
      name,
      period,
    }
  });
  console.log('existing:', existing);
  
  if (existing) {
    console.log('Error 400: Duplicate');
  } else {
    try {
      const budget = await prisma.budget.create({
        data: {
          userId: user.id,
          name,
          amount: 10000000,
          period,
        }
      });
      console.log('created:', budget);
    } catch (e) {
      console.error('Create error:', e);
    }
  }
}

test();
