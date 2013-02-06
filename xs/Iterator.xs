#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

MODULE = PDL::NDBin::Iterator	PACKAGE = PDL::NDBin::Iterator

SV *
advance( HV *self )
  PREINIT:
	AV  *active      = NULL;
	SV  *bin         = NULL,
	    *var         = NULL;
	SV **svp         = NULL,
	   **selection   = NULL,
	   **unflattened = NULL,
	   **want        = NULL;
	int  nbins       = -1,
	     nvars       = -1;
  CODE:
	if( (svp = hv_fetch(self, "bin", 3, FALSE)) ) bin = *svp;
	else croak( "advance: need bin" );
	if( (svp = hv_fetch(self, "nbins", 5, FALSE)) ) nbins = SvIV( *svp );
	else croak( "advance: need nbins" );
	/* check if already done */
	if( (int) SvIV(bin) >= nbins ) XSRETURN_UNDEF;
	if( (svp = hv_fetch(self, "var", 3, FALSE)) ) var = *svp;
	else croak( "advance: need var" );
	if( (svp = hv_fetch(self, "nvars", 5, FALSE)) ) nvars = SvIV( *svp );
	else croak( "advance: need nvars" );
	if( (svp = hv_fetch(self, "active", 6, FALSE)) ) {
		if( SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVAV ) {
			active = (AV *) SvRV( *svp );
		}
		else croak( "advance: active is of wrong type" );
	}
	else croak( "advance: need active" );
	selection = hv_fetch(self, "selection", 9, FALSE);
	unflattened = hv_fetch(self, "unflattened", 11, FALSE);
	want = hv_fetch(self, "want", 4, FALSE);
	for( ;; ) {
		sv_inc( var );
		/* invalidate cached data */
		if( selection ) {
			SvREFCNT_dec( *selection );
			*selection = newSVsv( &PL_sv_undef );
			selection = NULL;
		}
		if( (int) SvIV(var) >= nvars ) {
			sv_setiv( var, 0 );
			sv_inc( bin );
			/* done? */
			if( (int) SvIV(bin) >= nbins ) XSRETURN_UNDEF;
			/* invalidate cached data */
			if( want ) {
				SvREFCNT_dec( *want );
				*want = newSVsv( &PL_sv_undef );
				want = NULL;
			}
			if( unflattened ) {
				SvREFCNT_dec( *unflattened );
				*unflattened = newSVsv( &PL_sv_undef );
				unflattened = NULL;
			}
		}
		if( (svp = av_fetch(active, (I32) SvIV(var), FALSE)) ) {
			if( SvTRUE(*svp) ) break;
		}
		else croak( "advance: need state" );
	}
	XSRETURN_YES;
