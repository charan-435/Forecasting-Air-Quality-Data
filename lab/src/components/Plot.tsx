import createPlotlyComponent from "react-plotly.js/factory";
import Plotly from "plotly.js-basic-dist-min";
import { plotConfig } from "../lib/plotlyTheme";

const PlotlyChart = createPlotlyComponent(Plotly);

type Props = {
  data: object[];
  layout?: object;
  className?: string;
  height?: number;
  style?: React.CSSProperties;
};

export default function Plot({ data, layout, className, height = 300, style }: Props) {
  const h = height;
  return (
    <div className={className ?? "plot-box"} style={{ minHeight: h, height: h, ...style }}>
      <PlotlyChart
        data={data as never}
        layout={
          {
            autosize: true,
            height: h,
            ...(layout ?? {}),
          } as never
        }
        config={plotConfig as never}
        style={{ width: "100%", height: h }}
        useResizeHandler
      />
    </div>
  );
}
