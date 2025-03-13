# purin game / pudding game / プリンゲーム

![Banner_jp](https://github.com/user-attachments/assets/cadde4c9-4490-48f1-951c-61903bc0eeb3)
Inspired by Suika Game


Play for free on itch.io (In Browser or download for Windows/Linux)

https://shrikegames.itch.io/purin-game

![Screenshot_2024-08-03_13-57-34](https://github.com/user-attachments/assets/114e4417-caea-4073-a7fe-2e8195c15f22)

![celluloid-shot0353](https://github.com/user-attachments/assets/d60b249e-ad83-475f-a74f-eb934089b66e)

![celluloid-shot0355](https://github.com/user-attachments/assets/11591842-bdd5-454d-87ed-fed8c19ba795)

![celluloid-shot0354](https://github.com/user-attachments/assets/cd2c25b9-3dd7-48bc-8a68-eac12a38cdab)

![Screenshot_2024-08-03_13-56-19](https://github.com/user-attachments/assets/4f1aa5f5-213f-4950-b893-6b3e399fc908)


How the game works:
- The game takes place in a roughly 800x800 pixel box with an open top
- The player drops purin down from the top into the box, they cannot drop them outside the box
- Purin dropped will fall, bounce, and otherwise act as regular physics would expect
- Purin are round spheres and thus can also roll
- Purin can be of 10 different sizes, numbered 0 to 9
- Purin of the same size that touch combine into a purin of 1 size larger
- When purin combine the player gains score
- The score increase gained from purin is defined by the equation: int(pow(level + 1, 2)) * int(1 + (dropped_purin_count * 0.1))
- The larger the combine the more points it's worth, as well as how many total purin have been dropped in the game so combines get more valuable as the game goes on
- Purin get much larger when combined, the sizes of the purin in order are [50, 100, 125, 156, 175, 195, 250, 275, 300, 343]
- The challenge is trying to combine purin as much as possible and avoid filling the play area
- When two max level purin (9) are combined they disapear freeing up space
- Playing randomly you can get a score of 40,000 on average
- An intelligent player can get over 150k rarely
- To go combine two max level purin is extremely difficult but if you can it's in theory possible to go for a very long time and get much higher scores (I have never managed to do this, although have gotten close)
- Covering up smaller purin, especially purin that you know the next purin in your queue could merge with is bad and should be avoided
- The way it determines what purin you get to drop is similar to tetris in that it is random bag of purin of varying sizes.
  - The max size of purin that can be in the bag is half of the largest purin size achieved in the game, rounded down
  - It will fill the bag with one of each size in a random order up to the largest size it is allowed to generate
  - This ensures you'll get a variety without duplicates but cannot guarentee the order you will get them in

PPO Information:
1. Average Return
What It Represents:

	The average return is the average cumulative reward obtained by the agent over a set of episodes.

	It measures how well the agent is performing in the environment.

What You Want to See:

	Increasing Trend: As the agent learns, the average return should increase over time. This indicates that the agent is discovering better strategies to maximize rewards.

	Stabilization: Eventually, the average return should stabilize at a high value, indicating that the agent has converged to a good policy.

What to Watch Out For:

	Flat or Decreasing Trend: If the average return is not increasing or is decreasing, the agent may be stuck in a suboptimal policy or experiencing instability.

	High Variance: Large fluctuations in the average return may indicate that the agent is exploring too much or that the reward signal is noisy.

2. Average Advantage
What It Represents:

	The average advantage measures how much better or worse the agent’s actions are compared to the baseline (value function’s prediction).

	A positive advantage means the action was better than expected, while a negative advantage means it was worse.

What You Want to See:

	Stable and Slightly Positive: Ideally, the average advantage should stabilize around a small positive value. This indicates that the agent is consistently taking actions that are better than the baseline.

	Low Variance: The advantage should have low variance, indicating that the agent’s actions are consistently good.

What to Watch Out For:

	Large Positive or Negative Values: If the average advantage is too large (positive or negative), it may indicate that the value function is not well-trained or that the policy is unstable.

	High Variance: Large fluctuations in the advantage may indicate that the agent is exploring too much or that the reward signal is noisy.

3. Policy Loss
What It Represents:

	The policy loss measures how well the policy network is performing. It includes:

		The surrogate objective (how much the new policy improves over the old policy).

		The entropy bonus (encourages exploration).

What You Want to See:

	Decreasing Trend: Initially, the policy loss should decrease as the agent learns better policies.

	Stabilization: Eventually, the policy loss should stabilize at a low value, indicating that the policy has converged.

What to Watch Out For:

	Increasing or Oscillating Loss: If the policy loss increases or oscillates, it may indicate that the learning rate is too high, the policy updates are too large, or the entropy bonus is too strong.

	NaN or Inf: If the policy loss becomes NaN or inf, it may indicate numerical instability (e.g., due to exploding gradients or invalid probabilities).

4. Value Loss
What It Represents:

	The value loss measures how well the value function is predicting the returns. It is typically the mean squared error (MSE) between the predicted and actual returns.

What You Want to See:

	Decreasing Trend: Initially, the value loss should decrease as the value function learns to predict returns more accurately.

	Stabilization: Eventually, the value loss should stabilize at a low value, indicating that the value function has converged.

What to Watch Out For:

	Increasing or Oscillating Loss: If the value loss increases or oscillates, it may indicate that the learning rate is too high, the value function is overfitting, or the reward signal is noisy.

	NaN or Inf: If the value loss becomes NaN or inf, it may indicate numerical instability (e.g., due to exploding gradients or invalid inputs).
