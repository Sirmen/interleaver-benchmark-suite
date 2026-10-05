function hgca = setAxisLabelTicks(xData, yData, opt)
    hgca = gca;
    hgca.XTick = 1:length(xData);
    hgca.XTickLabel = xData;
    hgca.XTickLabelRotation = 45;
    hgca.YTickLabelRotation = 45;
    hgca.XAxis.FontSize = 10;
    yMin = min(yData); yMax = max(yData);
    ylim([yMin*0.8 yMax*1.03]);
    if opt
      hgca.YTick = linspace(yMin, yMax, 8);
    end
end
