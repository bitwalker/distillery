use Distillery.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()


environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :"b:3<,[s&!Itebrv,|sM;n3MvkmG4a0uF`R@4Zh7~VSv&*$5xh_=h~KBg/bq*k`*~"
end

environment :prod do
  set include_erts: false
  set include_src: false
  set cookie: :"UMSq<$cWFWDtMB*yl?o;7$ote.$Xcmh:z|!:]@U81}1RsDJzcC<1g8F3/g!gjom="
end


release :ordered_app do
  set version: current_version(:ordered_app)
  set applications: [:ordered_app]
end

