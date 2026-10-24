# 投球イニングの計算（ルールブック §8.2.4 関与イニング数）
# 長イニング敗戦判定（PitcherGameState）と累積イニング加算（PitcherGameStatesController）で共有する。
module PitcherInnings
  module_function

  # 野球表記の投球回（7.1 = 7回1/3）→ アウト数
  def outs_from_innings(innings_pitched)
    ip = innings_pitched.to_f
    ip.floor * 3 + ((ip * 10).round % 10)
  end

  # 関与イニング数 = 登板した回から降板した回までの数（途中の回から入ればその回も1と数える）
  #   start_inning = floor(prior_outs / 3) + 1
  #   end_inning   = floor((prior_outs + my_outs - 1) / 3) + 1
  #   関与 = (end_inning - start_inning + 1) + (no_out_exit ? 1 : 0)
  #   my_outs == 0（0アウト降板）の場合は 1
  # prior_outs: 同じ試合で自分より前に投げた同チーム投手の通算アウト数
  def involvement(innings_pitched, prior_outs: 0, no_out_exit: false)
    my_outs = outs_from_innings(innings_pitched)
    return 1 if my_outs == 0

    start_inning = prior_outs / 3 + 1
    end_inning = (prior_outs + my_outs - 1) / 3 + 1
    (end_inning - start_inning + 1) + (no_out_exit ? 1 : 0)
  end
end
